//
//  LiveVitalsExampleView.swift
//  SmartSpectraExamples
//
//  Copyright (c) 2025 Presage Technologies. All rights reserved.
//

import AVFoundation
import Combine
import SmartSpectraSwiftSDK
import SwiftUI
import UIKit

/// Demonstrates how to run a lightweight live capture loop with rolling vitals charts.
struct LiveVitalsExampleView: View {
  @StateObject private var session = LiveVitalsSession()

  private enum Layout {
    static let traceWindowSeconds: Double = 12
  }

  var body: some View {
    ZStack(alignment: .bottom) {
      CameraBackground(image: session.previewImage)
        .ignoresSafeArea()

      VStack(spacing: 16) {
        if let statusText = session.statusText {
          VStack(alignment: .leading, spacing: 0) {
            Text(statusText)
              .font(.title3.weight(.semibold))
              .multilineTextAlignment(.leading)
              .padding(16)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(.ultraThinMaterial)
              .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
              .padding(.horizontal)
          }
        }

        if session.isRecording {
          VitalsPlotsOverlay(
            pulseRate: session.pulseRate,
            breathingRate: session.breathingRate,
            pulseTrace: session.pulseTrace,
            breathingTrace: session.breathingTrace,
            windowSeconds: Layout.traceWindowSeconds
          )
          .transition(.move(edge: .bottom).combined(with: .opacity))
        }

        Button(action: session.toggleRecording) {
          Label(
            session.isRecording ? "Stop" : "Start",
            systemImage: session.isRecording ? "stop.circle.fill" : "play.circle.fill"
          )
          .font(.headline)
          .labelStyle(.titleAndIcon)
          .padding(.horizontal, 24)
          .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(session.isRecording ? .red : .accentColor)
        .disabled(!session.canToggleRecording)
      }
      .frame(maxWidth: 560)
      .padding(.vertical, 32)
      .padding(.horizontal, 20)
    }
    .background(Color.black.ignoresSafeArea())
    .navigationTitle("Live Vitals Preview")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(Color(.systemBackground), for: .navigationBar)
    .toolbarBackground(.visible, for: .navigationBar)
    .cameraPermissionGate()
    // Start the SmartSpectra processors once the view is active.
    .task { session.prepare() }
    .onDisappear { session.teardown() }
  }
}

/// Displays the raw SDK frame as a full-screen background while live capture runs.
private struct CameraBackground: View {
  let image: UIImage?

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        Color.black
        if let frame = image {
          Image(uiImage: frame)
            .resizable()
            .scaledToFill()
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        } else {
          ProgressView("Initializing camera…")
            .foregroundStyle(.white)
        }
      }
    }
    .ignoresSafeArea()
  }
}

/// Two stacked trace plots that visualise pulse and breathing samples in real time.
struct VitalsPlotsOverlay: View {
  let pulseRate: Int
  let breathingRate: Int
  let pulseTrace: [VitalSample]
  let breathingTrace: [VitalSample]
  let windowSeconds: Double

  var body: some View {
    VStack(spacing: 12) {
      VitalsTracePlotView(
        title: "Pulse\n\(pulseRate > 0 ? "\(pulseRate) bpm" : "--")",
        systemImage: "heart.fill",
        samples: pulseTrace,
        color: .red,
        windowSeconds: windowSeconds
      )
      .frame(height: 72)

      VitalsTracePlotView(
        title: "Breathing\n\(breathingRate > 0 ? "\(breathingRate) bpm" : "--")",
        systemImage: "lungs.fill",
        samples: breathingTrace,
        color: .blue,
        windowSeconds: windowSeconds
      )
      .frame(height: 72)
    }
    .padding(16)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }
}

@MainActor
/// Observable object that coordinates SmartSpectra capture for the live preview demo.
final class LiveVitalsSession: ObservableObject {
  @Published var previewImage: UIImage?
  @Published var statusHint: String?
  @Published var pulseRate: Int = 0
  @Published var breathingRate: Int = 0
  @Published var pulseTrace: [VitalSample] = []
  @Published var breathingTrace: [VitalSample] = []
  @Published var isRecording = false

  var statusText: String? {
    guard vitalsProcessor.lastStatusCode != .ok, let hint = statusHint, !hint.isEmpty else {
      return nil
    }
    return hint
  }

  var canToggleRecording: Bool {
    if isRecording { return true }
    guard isProcessorActive else { return false }
    return vitalsProcessor.lastStatusCode == .ok
  }

  private let smartSpectra = SmartSpectraSwiftSDK.shared
  private let vitalsProcessor = SmartSpectraVitalsProcessor.shared
  private var cancellables: Set<AnyCancellable> = []

  private let traceWindowSeconds: Double = 12
  private var isProcessorActive = false
  private var lastPulseTraceTimestamp: Double?
  private var lastBreathingTraceTimestamp: Double?
  private var recordingStart: Date?

  init() {
    bindStreams()
  }

  /// Configures SmartSpectra for live capture and primes the vitals processor.
  func prepare() {
    guard !isProcessorActive else { return }
    smartSpectra.setSmartSpectraMode(.continuous)
    smartSpectra.setCameraPosition(.front)
    smartSpectra.setImageOutputEnabled(true)
    smartSpectra.resetMetrics()

    vitalsProcessor.startProcessing()
    isProcessorActive = true
  }

  /// Toggles the SmartSpectra recording loop while respecting processor readiness.
  func toggleRecording() {
    guard isProcessorActive else { return }
    if isRecording {
      stopRecording()
    } else {
      startRecording()
    }
  }

  /// Stops recording and shuts down the processor when the view disappears.
  func teardown() {
    stopRecording()
    recordingStart = nil
    guard isProcessorActive else { return }

    vitalsProcessor.stopProcessing()
    smartSpectra.resetMetrics()
    isProcessorActive = false
  }

  private func startRecording() {
    smartSpectra.resetMetrics()
    pulseRate = 0
    breathingRate = 0
    pulseTrace = []
    breathingTrace = []
    lastPulseTraceTimestamp = nil
    lastBreathingTraceTimestamp = nil
    recordingStart = Date()
    vitalsProcessor.startRecording()
  }

  private func stopRecording() {
    guard vitalsProcessor.isRecording else { return }
    vitalsProcessor.stopRecording()
    recordingStart = nil
  }

  /// Subscribes to the SDK publishers and mirrors updates into SwiftUI state.
  private func bindStreams() {
    vitalsProcessor.$imageOutput
      .receive(on: RunLoop.main)
      .sink { [weak self] image in
        self?.previewImage = image
      }
      .store(in: &cancellables)

    vitalsProcessor.$statusHint
      .receive(on: RunLoop.main)
      .sink { [weak self] hint in
        guard let self else { return }
        let trimmed = hint.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
          statusHint = trimmed
        }
      }
      .store(in: &cancellables)

    vitalsProcessor.$isRecording
      .receive(on: RunLoop.main)
      .sink { [weak self] recording in
        self?.isRecording = recording
      }
      .store(in: &cancellables)

    smartSpectra.$metricsBuffer
      .receive(on: RunLoop.main)
      .sink { [weak self] buffer in
        guard let self, let buffer else { return }
        ingest(buffer: buffer)
      }
      .store(in: &cancellables)

    smartSpectra.$edgeMetrics
      .receive(on: RunLoop.main)
      .sink { [weak self] metrics in
        guard let self, let metrics else { return }
        ingest(edgeMetrics: metrics)
      }
      .store(in: &cancellables)
  }

  private func ingest(buffer: Presage_Physiology_MetricsBuffer) {
    guard isRecording else { return }

    if let latestPulse = buffer.pulse.rate.last {
      pulseRate = max(0, Int(latestPulse.value.rounded()))
    }
    if let latestBreathing = buffer.breathing.rate.last {
      breathingRate = max(0, Int(latestBreathing.value.rounded()))
    }

    let baseTimestamp: Double = if buffer.hasMetadata {
      Double(buffer.metadata.sentAtS)
    } else {
      Date().timeIntervalSince1970
    }

    if !buffer.pulse.trace.isEmpty {
      var updated = pulseTrace
      for sample in buffer.pulse.trace {
        let timestamp = baseTimestamp + Double(sample.time)
        guard lastPulseTraceTimestamp.map({ timestamp > $0 }) ?? true else { continue }
        updated.append(VitalSample(time: timestamp, value: Double(sample.value)))
        lastPulseTraceTimestamp = timestamp
      }
      pulseTrace = updated
    }
  }

  private func ingest(edgeMetrics: Presage_Physiology_Metrics) {
    guard isRecording else { return }

    let baseTimestamp = recordingStart?.timeIntervalSince1970 ?? Date().timeIntervalSince1970

    if !edgeMetrics.breathing.upperTrace.isEmpty {
      var updated = breathingTrace
      for sample in edgeMetrics.breathing.upperTrace {
        let timestamp = baseTimestamp + Double(sample.time)
        guard lastBreathingTraceTimestamp.map({ timestamp > $0 }) ?? true else { continue }
        updated.append(VitalSample(time: timestamp, value: Double(sample.value)))
        lastBreathingTraceTimestamp = timestamp
      }
      breathingTrace = updated
    }
  }


}
