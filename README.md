# SmartSpectraSwiftSDK iOS Examples

Sample SwiftUI application showcasing three integration patterns for the [SmartSpectra Swift SDK](https://github.com/Presage-Security/SmartSpectra):

- **SmartSpectra Capture Experience** – Launch the SDK's built-in guided capture UX via `SmartSpectraView` with minimal configuration.
- **Pulse Capture Form** – Trigger a capture flow, validate the returned reading, and drop the result into a read-only form field.
- **Live Vitals Preview** – Run a lightweight capture loop with start/stop controls and rolling charts for pulse and breathing traces.

## Requirements

- Xcode 16.0 or later
- iOS 17 (device deployment target is 17.0)
- Physical iOS device (camera access is required; the simulator is not supported)
- SmartSpectra developer account

## Getting Started

1. **Clone the repository**
   ```bash
   git clone https://github.com/Presage-Security/SmartSpectraSwiftSDK-Examples.git
   cd SmartSpectraExamples
   ```
2. **Install credentials**
   - Sign in (or create an account) at [https://physiology.presagetech.com/](https://physiology.presagetech.com/).
   - Register your app in the portal and download the generated `PresageService-Info.plist` configuration.
   - In this repo, copy the provided `SmartSpectraExamples/PresageService-Info.example.plist` to `SmartSpectraExamples/PresageService-Info.plist` and replace the placeholder values with the credentials from the portal. (The real plist is ignored by source control so you can keep secrets out of git.)
3. **Open the project**
   - Double-click `SmartSpectraExamples.xcodeproj`, or run `xed .` from the repo root.
   - Select the `SmartSpectraExamples` target and configure your signing team and bundle identifier.
4. **Build on a device**
   - Connect your iOS device, select it as the run destination, then build and run. Grant camera access when prompted.

> **Heads up**: If you prefer API-key authentication over the portal configuration, call `SmartSpectraSwiftSDK.shared.setApiKey("YOUR_API_KEY")` early in your app lifecycle (e.g., in `configureSdk()` inside `SmartSpectraExperienceExampleView`).

## Project Structure

`SmartSpectraExamples/ContentView.swift` | Entry point that lists the available demos and surfaces a quick link back to this GitHub repository. Add your own examples to `ExampleCatalog` to make them appear automatically.
`SmartSpectraExamples/Examples/SmartSpectraExperience/SmartSpectraExperienceExampleView.swift` | Launches `SmartSpectraView` (the SDK’s guided UX) and surfaces a lightweight metrics summary from the shared SDK instance.
`SmartSpectraExamples/Examples/PulseCaptureInForm/PulseFormExampleView.swift` | SwiftUI form demonstrating how to feed a confirmed pulse reading into a read-only form field.
`SmartSpectraExamples/Examples/PulseCaptureInForm/PulseCaptureView.swift` | Reusable capture sheet that wraps `SmartSpectraSwiftSDK` / `SmartSpectraVitalsProcessor` and publishes progress, confidence, and resulting measurements.
`SmartSpectraExamples/Examples/LiveVitalsPreview/LiveVitalsExampleView.swift` | Minimal capture loop that shows a live camera preview, start/stop button, and rolling pulse/breathing charts.
`SmartSpectraExamples/Examples/LiveVitalsPreview/VitalsTracePlotView.swift` | Timeline-driven renderer that animates the vitals traces while recordings run.
`SmartSpectraExamples/Examples/LiveVitalsPreview/VitalSample.swift` | Lightweight model used to plot vitals samples over time.
`SmartSpectraExamples/Core/CameraPermissionGate.swift` | `ViewModifier` that prompts users for camera access when required.

## What’s Inside Each Demo

- **SmartSpectra Capture Experience**
  - Minimal configuration via `SmartSpectraExperienceExampleView.Config` (mode, camera, duration, control visibility).
  - Pulls latest vitals from `SmartSpectraSwiftSDK.shared.metricsBuffer` to show current pulse/breathing readings.

- **Live Vitals Preview**
  - Spins up `SmartSpectraVitalsProcessor.shared` once on appear, then lets you start/stop recordings without reinitialising the processor.
  - Uses `VitalsPlotsOverlay` to render pulse and breathing rate traces in real time while the camera feed fills the background.
  - `VitalsTracePlotView` extends the most recent sample between SDK updates so the charts stay responsive.

- **Pulse Capture Form**
  - `PulseFormExampleView` owns the read-only field and launches a capture sheet.
  - `PulseCaptureView` collects data, enforces confidence thresholds, and hands back a `PulseCaptureReading` when users tap **Use Reading**.
  - `ReadOnlyMeasurementField` gives visual affordance of a text field without allowing manual edits.

## Customization Tips

- Adjust `SmartSpectraExperienceExampleView.Config` to experiment with mode, camera position, or measurement duration.
- The pulse form example stores the latest reading in `PulseCaptureReading` and formats it for display; you can replace the read-only view with your own form controls.
- `PulseCaptureSession` wraps `SmartSpectraSwiftSDK.shared` and `SmartSpectraVitalsProcessor.shared`. Extend it if you need to stream additional metrics or surface custom status messages.
- `LiveVitalsSession` demonstrates how to consume `SmartSpectraVitalsProcessor` and `SmartSpectraSwiftSDK` publishers directly. Tune the `windowSeconds` constant to adjust how much history each chart displays.

## Troubleshooting

- **Camera access denied** – Users must enable camera permissions in Settings; `CameraPermissionGate` surfaces a prompt if access is missing.
- **No confident pulse captured** – Ensure good lighting and face positioning; the session will return an error label and you can retry the capture.
- **Build failures fetching packages** – From Xcode, open *File ▸ Packages ▸ Reset Package Caches* and rebuild.

## License

See [LICENSE](LICENSE) for license information (update this section to match your project’s license).
