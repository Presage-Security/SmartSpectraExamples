# Agent Guide

These samples target developers exploring integration patterns for the SmartSpectra SDK. Architect each feature to stay focused on demonstrating SDK usage, favouring straightforward flows, minimal dependencies, and cleanly separated code that is easy to trace.

## App Entry & SDK Setup
- `SmartSpectraExamplesApp.swift` launches `ContentView` inside the sole `WindowGroup`; there is no global `configureSdk()`, so screens configure the SDK when they appear.
- `SmartSpectraExperienceExampleView.configureSdk()` sets the shared `SmartSpectraSwiftSDK` mode, camera, measurement duration, and whether the built-in controls show. Call `setApiKey(_:)` earlier in your flow if you prefer API-key auth.
- All capture-oriented views apply `.cameraPermissionGate()` so the modifier in `Core/CameraPermissionGate.swift` can request authorization, watch `scenePhase`, and open Settings when access is denied.

## Demo Catalog & Navigation
- `ContentView.swift` wraps the samples in a `NavigationStack` with a single `Section("Available Examples")`.
- `ExampleCatalog` defines the `Example` model and registers the three demos currently bundled: `.sdkExperience`, `.pulseInput`, and `.liveVitals`.
- Add new demos by extending both the `examples` array and the `navigationDestination` switch, then placing their SwiftUI views under `SmartSpectraExamples/Examples/<Feature>`.

## Example Implementations
### SmartSpectra Experience
- `Examples/SmartSpectraExperience/SmartSpectraExperienceExampleView.swift` presents `SmartSpectraView` inside a card, configures the shared SDK on appear, and pulls pulse/breathing summaries from `SmartSpectraSwiftSDK.shared.metricsBuffer`.
- The metrics section already guards against missing readings and timestamps; copy the pattern if you surface additional vitals.

### Pulse Capture In Form
- `Examples/PulseCaptureInForm/PulseFormExampleView.swift` owns the form UI, launches a sheet to capture pulse, and reflects the last accepted reading in a read-only `ReadOnlyMeasurementField`.
- `PulseCaptureView.swift` renders the modal capture flow, coordinating a `PulseCaptureSession`, live preview, status messaging, and the **Use Reading** / **Cancel** actions.
- `PulseCaptureSession` wraps `SmartSpectraSwiftSDK.shared` and `SmartSpectraVitalsProcessor.shared`, averages up to 50 confident readings, exposes `commitMeasurement()`, and produces `PulseCaptureReading` values for the form.

### Live Vitals Preview
- `Examples/LiveVitalsPreview/LiveVitalsExampleView.swift` layers a camera background, status hints, start/stop toggle, and rolling charts while recording is active.
- `LiveVitalsSession` binds SDK publishers, trims trace buffers to a 12-second window, and only enables toggling when the processor is ready.
- `VitalSample.swift` and `VitalsTracePlotView.swift` live alongside the view; `VitalsTracePlotView` animates via `TimelineView` and extends the last sample so charts stay responsive between updates.

## Core Utilities
- `Core/CameraPermissionGate.swift` houses both the `cameraPermissionGate()` modifier and the `CameraPermission` helper. It requests access on first run, skips prompts on the simulator, and opens Settings for denied states.

## Resources & Configuration
- `Assets.xcassets` currently includes `AppIcon.appiconset` and `AccentColor.colorset` only.
- `PresageService-Info.example.plist` documents the required keys. `PresageService-Info.plist` is checked in with sample identifiers—replace them with environment-specific credentials before shipping.
- No additional resource bundles or localization files ship with the project.

## Tooling & Formatting
- `.swift-version` pins the toolchain to Swift 6; use the Swift 6 compiler when building locally.
- `.swiftformat` configures SwiftFormat (indent 2 spaces, wrap args/collections before first element, strip unused closure args, enforce lowercase hex/exponent, and inject the shared file header). Run `swiftformat .` to standardize new files.

## Coding Style
- Swift 6 sources use two-space indentation, trailing commas in multi-line literals, and `guard` for early exits.
- Prefer concise comments that clarify SDK integration or non-obvious behaviour; current sources rely on self-documenting code elsewhere.
