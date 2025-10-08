//
//  ContentView.swift
//  SmartSpectraExamples
//
//  Copyright (c) 2025 Presage Technologies. All rights reserved.
//

import SwiftUI

struct ContentView: View {
  private let catalog = ExampleCatalog.examples

  /// Lists every demo registered in `ExampleCatalog` and routes to the matching showcase screen.
  var body: some View {
    NavigationStack {
      List {
        Section("Available Examples") {
          ForEach(catalog) { example in
            NavigationLink(value: example.id) {
              ExampleRowView(example: example)
            }
          }
        }
      }
      .navigationTitle("SmartSpectra Examples")
      // Keep the navigation switch in sync with `ExampleCatalog` whenever you add a new sample.
      .navigationDestination(for: Example.Identifier.self) { identifier in
        switch identifier {
        case .sdkExperience:
          SmartSpectraExperienceExampleView()
        case .pulseInput:
          PulseFormExampleView()
        case .liveVitals:
          LiveVitalsExampleView()
        }
      }
    }
  }
}

private struct ExampleRowView: View {
  let example: Example

  /// Displays the summary for a demo inside the list of available examples.
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(example.title)
        .font(.headline)
      Text(example.summary)
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 4)
  }
}

struct Example: Identifiable {
  /// Unique identifiers that match the routes declared in the navigation destination below.
  enum Identifier: Hashable {
    case sdkExperience
    case pulseInput
    case liveVitals
  }

  let id: Identifier
  let title: String
  let summary: String
}

enum ExampleCatalog {
  // Central place to register demo screens so they automatically appear in the navigation list above.
  static let examples: [Example] = [
    Example(
      id: .sdkExperience,
      title: "SmartSpectra Capture Experience",
      summary: "Launch the SDK-provided SmartSpectraView flow to guide participants through a full vitals capture session."
    ),
    Example(
      id: .pulseInput,
      title: "Pulse Capture Form",
      summary: "Embed a pulse measurement step in a SwiftUI form and persist the confirmed reading."
    ),
    Example(
      id: .liveVitals,
      title: "Live Vitals Preview",
      summary: "Show a live camera feed with start/stop controls and pulse/breathing charts."
    ),
  ]
}

#Preview {
  ContentView()
}
