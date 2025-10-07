//
//  ContentView.swift
//  SmartSpectraExamples
//
//  Copyright (c) 2025 Presage Technologies. All rights reserved.
//

import SwiftUI

struct ContentView: View {
  private let catalog = ExampleCatalog.examples

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
      // Resolve a destination for every registered sample so the list above can stay declarative.
      .navigationDestination(for: Example.Identifier.self) { identifier in
        switch identifier {
        case .sdkExperience:
          SmartSpectraExperienceExampleView()
        case .pulseInput:
          PulseFormExampleView()
        }
      }
    }
  }
}

private struct ExampleRowView: View {
  let example: Example

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
  enum Identifier: Hashable {
    case sdkExperience
    case pulseInput
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
  ]
}

#Preview {
  ContentView()
}
