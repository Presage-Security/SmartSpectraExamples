//
//  SmartSpectraExperienceExampleView.swift
//  SmartSpectraExamples
//
//  Copyright (c) 2025 Presage Technologies. All rights reserved.
//

import AVFoundation
import SmartSpectraSwiftSDK
import SwiftUI

/// Minimal wrapper that showcases the SDK-provided SmartSpectraView UX.
struct SmartSpectraExperienceExampleView: View {
  @ObservedObject private var sdk = SmartSpectraSwiftSDK.shared

  private enum Config {
    // These presets demonstrate the out-of-the-box SmartSpectra UX with minimal tweaks.
    static let mode: SmartSpectraMode = .continuous
    static let camera: AVCaptureDevice.Position = .front
    static let measurementDuration: Double = 30
    static let showsBuiltInControls = true
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        introSection
        smartSpectraCard
        metricsSection
      }
      .padding(24)
      .frame(maxWidth: 640)
      .frame(maxWidth: .infinity)
    }
    .background(Color(.systemGroupedBackground).ignoresSafeArea())
    .navigationTitle("SmartSpectra UX")
    .navigationBarTitleDisplayMode(.inline)
    .cameraPermissionGate()
    .onAppear(perform: configureSdk)
  }

  private var introSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Guided Capture Experience")
        .font(.title2.weight(.semibold))
      Text(
        "SmartSpectraView delivers the SDK's fully guided capture flow, handling onboarding, video capture, and result screens for you."
      )
      .font(.callout)
      .foregroundStyle(.secondary)
    }
  }

  private var smartSpectraCard: some View {
    SmartSpectraView()
      .frame(maxWidth: .infinity)
      .frame(minHeight: 420)
      .background(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .fill(Color(.secondarySystemBackground))
      )
      .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
      .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 8)
  }

  @ViewBuilder
  private var metricsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Latest Metrics")
        .font(.title3.weight(.semibold))

      if let metrics = sdk.metricsBuffer {
        // The shared SDK caches the latest metrics buffer so we can surface quick summaries.
        if let pulse = metrics.pulse.rate.last {
          let bpm = Int(pulse.value.rounded())
          let confidence = Int(pulse.confidence.rounded())
          Text("Pulse: \(bpm) BPM (confidence \(confidence))")
        }

        if let breathing = metrics.breathing.rate.last {
          let breathsPerMinute = Int(breathing.value.rounded())
          Text("Breathing: \(breathsPerMinute) breaths/min")
        }

        if metrics.hasMetadata {
          Text("Updated: \(metrics.metadata.uploadTimestamp)")
            .foregroundStyle(.secondary)
        }

        if metrics.pulse.rate.last == nil, metrics.breathing.rate.last == nil {
          Text("No summary metrics in the latest buffer.")
            .foregroundStyle(.secondary)
        }
      } else {
        Text("Start a capture to view pulse and breathing summaries here.")
          .foregroundStyle(.secondary)
      }
    }
    .padding(20)
    .background(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(Color(.secondarySystemBackground))
    )
  }

  private func configureSdk() {
    // Configure shared SDK state once when the screen appears. If your app uses API-key based auth,
    // call `sdk.setApiKey(_:)` earlier in your flow before presenting this view.
    sdk.setSmartSpectraMode(Config.mode)
    sdk.setCameraPosition(Config.camera)
    sdk.setMeasurementDuration(Config.measurementDuration)
    sdk.showControlsInScreeningView(Config.showsBuiltInControls)
  }
}

#Preview {
  NavigationStack {
    SmartSpectraExperienceExampleView()
  }
}
