//
//  PulseCaptureView.swift
//  SmartSpectraExamples
//
//  Copyright (c) 2025 Presage Technologies. All rights reserved.
//

import AVFoundation
import Combine
import SmartSpectraSwiftSDK
import SwiftUI
import UIKit

/// Lightweight model the form view uses to store the most recent capture.
struct PulseCaptureReading: Equatable {
  let bpm: Int
  let capturedAt: Date

  var bpmString: String { String(bpm) }
  var formattedBpm: String { "\(bpm) BPM" }
  var formattedTimestamp: String {
    capturedAt.formatted(date: .abbreviated, time: .shortened)
  }
}

/// Full-screen sheet that guides the user through capturing a pulse measurement.
struct PulseCaptureView: View {
  @Environment(\.dismiss) private var dismiss
  @StateObject private var model: PulseCaptureSession

  private let onComplete: (PulseCaptureReading) -> Void

  init(initialReading: PulseCaptureReading?, onComplete: @escaping (PulseCaptureReading) -> Void) {
    _model = StateObject(wrappedValue: PulseCaptureSession(initialReading: initialReading))
    self.onComplete = onComplete
  }

  var body: some View {
    NavigationStack {
      ZStack {
        Color(.systemBackground)
          .ignoresSafeArea()

        VStack(spacing: 16) {
          CameraPreview(image: model.previewImage)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)

          VStack(spacing: 8) {
            if let averagePulse = model.averageConfidentPulse {
              Text("Confident Pulse: \(averagePulse) BPM")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.green)
            } else if let livePulse = model.livePulse {
              Text("Stabilizing Pulse: \(livePulse) BPM")
                .font(.title3.weight(.semibold))
            }

            Text(model.statusMessage)
              .multilineTextAlignment(.center)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }

          if let error = model.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle.fill")
              .font(.footnote)
              .foregroundStyle(.yellow)
          }

          Button {
            model.toggleRecording()
          } label: {
            Label(
              model.isRecording ? "Stop Capture" : "Start Capture",
              systemImage: model.isRecording ? "stop.circle" : "play.circle"
            )
            .font(.headline)
            .labelStyle(.titleAndIcon)
          }
          .buttonStyle(.borderedProminent)
          .tint(model.isRecording ? .red : .accentColor)
          .disabled(!model.canToggleRecording)
        }
        .frame(maxWidth: 520)
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .top)
      }
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            model.teardown()
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Use Reading") {
            guard let reading = model.commitMeasurement() else { return }
            onComplete(reading)
            dismiss()
          }
          .disabled(!model.canFinalize)
        }
      }
      .navigationTitle("Capture Pulse")
      .navigationBarTitleDisplayMode(.inline)
    }
    // Spin up the SmartSpectra pipelines when presented and shut them down when the sheet closes.
    .onAppear { model.prepareSession() }
    .onDisappear { model.teardown() }
  }
}

/// Displays the latest frame coming from the SDK while maintaining a square aspect ratio.
private struct CameraPreview: View {
  let image: UIImage?

  var body: some View {
    GeometryReader { geometry in
      let side = min(geometry.size.width, geometry.size.height)

      ZStack {
        RoundedRectangle(cornerRadius: 16)
          .fill(.secondary.opacity(0.12))

        if let uiImage = image {
          Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
            .frame(width: side, height: side)
            .clipped()
        } else {
          ProgressView("Preparing camera…")
            .padding()
        }
      }
      .frame(width: side, height: side)
      .clipShape(RoundedRectangle(cornerRadius: 16))
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .strokeBorder(.white.opacity(0.2), lineWidth: 1)
      )
      .position(x: geometry.size.width / 2, y: side / 2)
    }
    .aspectRatio(1, contentMode: .fit)
  }
}

@MainActor
/// Small wrapper around the shared SDK singletons that keeps the capture view declarative.
private final class PulseCaptureSession: ObservableObject {
  @Published var previewImage: UIImage?
  @Published var statusMessage = "Ready to capture."
  @Published var livePulse: Int?
  @Published var isRecording = false
  @Published var errorMessage: String?

  @Published var confidentReadings: [Presage_Physiology_MeasurementWithConfidence] = []
  var averageConfidentPulse: Int? {
    guard !confidentReadings.isEmpty else { return nil }
    let sum = confidentReadings.reduce(0.0) { partial, reading in
      partial + Double(reading.value)
    }
    let avg = sum / Double(confidentReadings.count)
    return Int(avg.rounded())
  }

  @Published private(set) var measurement: PulseCaptureReading?
  var statusCode: StatusCode { vitalsProcessor.lastStatusCode }
  var canFinalize: Bool { measurement != nil && !isRecording }
  var canToggleRecording: Bool { isRecording || vitalsProcessor.lastStatusCode == .ok }

  // The SDK exposes shared singletons; we keep references here so the view model can coordinate state.
  private let smartSpectra = SmartSpectraSwiftSDK.shared
  private let vitalsProcessor = SmartSpectraVitalsProcessor.shared
  private var cancellables: Set<AnyCancellable> = []
  private var hasActiveSession = false
  private let maxConfidentReadings: Int = 50

  init(initialReading: PulseCaptureReading?) {
    self.measurement = initialReading
    bindStreams()
  }

  func prepareSession() {
    smartSpectra.setSmartSpectraMode(.continuous)
    smartSpectra.setCameraPosition(.front)
    smartSpectra.setImageOutputEnabled(true)
    smartSpectra.resetMetrics()
    vitalsProcessor.startProcessing()
    statusMessage = "Position the camera in front of the participant."
  }

  func toggleRecording() {
    if isRecording {
      stopRecording()
    } else {
      guard canToggleRecording else { return }
      startRecording()
    }
  }

  func commitMeasurement() -> PulseCaptureReading? {
    measurement
  }

  func teardown() {
    stopRecording()
    vitalsProcessor.stopProcessing()
    smartSpectra.resetMetrics()
  }

  private func bindStreams() {
    // Mirror the SDK publishers onto @Published properties that SwiftUI reads.
    vitalsProcessor.$imageOutput
      .receive(on: RunLoop.main)
      .sink { [weak self] image in
        self?.previewImage = image
      }
      .store(in: &cancellables)

    smartSpectra.$metricsBuffer
      .receive(on: RunLoop.main)
      .compactMap { buffer -> Presage_Physiology_MeasurementWithConfidence? in
        guard let buffer else { return nil }
        guard let latest = buffer.pulse.rate.last else { return nil }
        return latest
      }
      .sink { [weak self] measurement in
        guard let self else { return }
        // Show a live pulse rate while we wait for a confident window of data.
        livePulse = Int(measurement.value.rounded())
        if measurement.confidence > 0 {
          insertConfidentReading(measurement)
        }
      }
      .store(in: &cancellables)

    vitalsProcessor.$statusHint
      .receive(on: RunLoop.main)
      .sink { [weak self] hint in
        guard let self else { return }
        let trimmed = hint.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
          // The SDK emits friendly hints ("Move closer", etc.); surface them directly.
          statusMessage = trimmed
        }
      }
      .store(in: &cancellables)

    vitalsProcessor.$isRecording
      .receive(on: RunLoop.main)
      .sink { [weak self] recording in
        guard let self else { return }
        isRecording = recording
        if !recording {
          // When recording stops (manually or automatically) consolidate the buffered data.
          handleRecordingStopped()
        }
      }
      .store(in: &cancellables)
  }

  private func insertConfidentReading(_ reading: Presage_Physiology_MeasurementWithConfidence) {
    // If we have room, just append.
    if confidentReadings.count < maxConfidentReadings {
      confidentReadings.append(reading)
      return
    }

    // Find the index of the lowest-confidence reading currently stored.
    if let minIndex = confidentReadings.enumerated().min(by: { lhs, rhs in
      lhs.element.confidence < rhs.element.confidence
    })?.offset {
      // Replace the lowest-confidence reading only if the new one is more confident.
      if reading.confidence > confidentReadings[minIndex].confidence {
        confidentReadings[minIndex] = reading
      }
    }
  }

  private func startRecording() {
    errorMessage = nil
    statusMessage = "Initialising capture…"
    smartSpectra.resetMetrics()

    livePulse = nil
    measurement = nil
    confidentReadings.removeAll()
    hasActiveSession = true
    // Kick off SmartSpectra data collection; completion is signalled back via the publishers.
    vitalsProcessor.startRecording()
    statusMessage = "Hold steady while we capture the pulse."
  }

  private func stopRecording() {
    guard vitalsProcessor.isRecording else { return }
    vitalsProcessor.stopRecording()
  }

  private func handleRecordingStopped() {
    guard hasActiveSession else { return }
    hasActiveSession = false

    // Require at least one confident reading before committing a measurement back to the form.
    guard let bpm = averageConfidentPulse, bpm > 0 else {
      measurement = nil
      statusMessage = "No confident pulse detected. Try again."
      errorMessage = "No confident pulse captured during the session."
      return
    }

    measurement = PulseCaptureReading(bpm: bpm, capturedAt: Date())
    statusMessage = "Capture complete."
    errorMessage = nil
  }
}
