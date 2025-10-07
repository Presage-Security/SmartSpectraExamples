//
//  PulseFormExampleView.swift
//  SmartSpectraExamples
//
//  Copyright (c) 2025 Presage Technologies. All rights reserved.
//

import SwiftUI

struct PulseFormExampleView: View {
  @Environment(\.scenePhase) private var scenePhase
  @State private var latestReading: PulseCaptureReading?
  @State private var isPresentingCapture = false
  @State private var cameraStatus = CameraPermission.status()
  @State private var captureDetent: PresentationDetent = .large
  // Store the formatted value that backs the read-only form row.
  @State private var pulseFieldValue = ""

  var body: some View {
    Form {
      introSection

      Section("Form Entry") {
        // Display the latest accepted measurement where a user would normally type a value.
        // Keeping it read-only reinforces that data must come from an SDK-backed capture.
        ReadOnlyMeasurementField(
          title: "Pulse (BPM)",
          value: pulseFieldValue,
          unit: "BPM",
          placeholder: "Tap Capture Pulse to fill this field"
        )

        Text("The measurement populates this read-only field once you accept a confident capture.")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .padding(.top, 4)
      }

      Section("Pulse Measurement") {
        Button {
          captureDetent = .large
          isPresentingCapture = true
        } label: {
          Label {
            Text("Capture Pulse")
              .fontWeight(.semibold)
          } icon: {
            Image(systemName: "camera.aperture")
              .symbolRenderingMode(.monochrome)
              .foregroundStyle(.white)
          }
          .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .frame(maxWidth: .infinity, alignment: .center)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .disabled(!isCameraCaptureAvailable)

        if cameraStatus == .denied || cameraStatus == .restricted {
          Text("Enable camera access in Settings to capture pulse data.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }

      if let reading = latestReading {
        Section("Last Capture") {
          LabeledContent("Reading") {
            Text(reading.formattedBpm)
          }
          LabeledContent("Collected") {
            Text(reading.formattedTimestamp)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
    .navigationTitle("Pulse Capture Form")
    .navigationBarTitleDisplayMode(.inline)
    .cameraPermissionGate()
    .sheet(isPresented: $isPresentingCapture) {
      PulseCaptureView(initialReading: latestReading) { reading in
        latestReading = reading
        pulseFieldValue = reading.bpmString
      }
      .presentationDetents([.large], selection: $captureDetent)
      .presentationDragIndicator(.hidden)
    }
    .onChange(of: scenePhase, initial: false) { _, newPhase in
      guard newPhase == .active else { return }
      cameraStatus = CameraPermission.status()
    }
    .onChange(of: latestReading, initial: true) { _, reading in
      // Ensure the synthetic field always mirrors the most recent capture, even after a view refresh.
      pulseFieldValue = reading?.bpmString ?? ""
    }
  }
}

private extension PulseFormExampleView {
  var introSection: some View {
    Section {
      VStack(alignment: .leading, spacing: 8) {
        Text("Capture Pulse Into Your Form")
          .font(.headline)
        Text(
          "Launch the SmartSpectra capture flow, confirm a confident pulse reading, and we will drop the result straight into this form entry."
        )
        .font(.callout)
        .foregroundStyle(.secondary)
      }
      .padding(.vertical, 4)
    }
  }

  var isCameraCaptureAvailable: Bool {
    switch cameraStatus {
    case .denied, .restricted:
      false
    default:
      true
    }
  }
}

// Visual affordance that looks like a form text field while remaining read-only.
private struct ReadOnlyMeasurementField: View {
  let title: String
  let value: String
  let unit: String?
  let placeholder: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.footnote)
        .foregroundStyle(.secondary)

      Text(displayValue)
        .font(.body)
        .foregroundStyle(value.isEmpty ? .secondary : .primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(Color(.separator))
        )
        .background(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(.systemBackground))
        )
    }
  }

  private var displayValue: String {
    if value.isEmpty {
      return placeholder
    }
    if let unit, !unit.isEmpty {
      return "\(value) \(unit)"
    }
    return value
  }
}

#Preview {
  NavigationStack {
    PulseFormExampleView()
  }
}
