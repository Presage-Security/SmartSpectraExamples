//
//  VitalsTracePlotView.swift
//  SmartSpectraExamples
//
//  Copyright (c) 2025 Presage Technologies. All rights reserved.
//

import SwiftUI

/// Simplified oscilloscope-style plot that scrolls through recent vital samples.
struct VitalsTracePlotView: View {
  let title: String
  let systemImage: String
  let samples: [VitalSample]
  let color: Color
  let windowSeconds: Double
  @State private var lastSampleDate: Date?

  var body: some View {
    GeometryReader { rowGeo in
      HStack {
        Label(title, systemImage: systemImage)
          .font(.headline)
        Spacer()
        ZStack {
          plot()
          if samples.isEmpty {
            Text("Awaiting signal…")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        .shadow(color: .white.opacity(0.35), radius: 3)
        .frame(width: rowGeo.size.width * 0.6, height: rowGeo.size.height)
      }
    }
  }

  private func plot() -> some View {
    // TimelineView ensures the trace scrolls smoothly even when samples arrive sporadically.
    TimelineView(.periodic(from: .now, by: 1.0 / 20.0)) { timeline in
      GeometryReader { geo in
        Path { path in
          guard let context = plotContext(for: timeline.date) else { return }
          draw(
            window: context.window,
            minValue: context.minValue,
            maxValue: context.maxValue,
            windowStart: context.windowStart,
            size: geo.size,
            path: &path
          )
        }
        .stroke(color, lineWidth: 2)
        .clipped()
      }
    }
    .onAppear(perform: syncTailAnchor)
    .onChange(of: samples.last?.time) { syncTailAnchor() }
  }

  private func plotContext(for timelineDate: Date) -> PlotContext? {
    guard let points = samplesIncludingTail(at: timelineDate),
          let latest = points.last
    else { return nil }

    let windowStart = latest.time - windowSeconds
    let window = points.drop { $0.time < windowStart }
    guard window.count > 1,
          let minVal = window.lazy.map(\.value).min(),
          let maxVal = window.lazy.map(\.value).max()
    else { return nil }

    return PlotContext(window: window, minValue: minVal, maxValue: maxVal, windowStart: windowStart)
  }

  private func samplesIncludingTail(at timelineDate: Date) -> [VitalSample]? {
    guard !samples.isEmpty else { return nil }
    var points = samples
    let anchor = lastSampleDate ?? timelineDate
    let elapsed = max(0, timelineDate.timeIntervalSince(anchor))
    if elapsed > 0, let last = points.last {
      points.append(VitalSample(time: last.time + elapsed, value: last.value))
    }
    return points
  }

  private func syncTailAnchor() {
    lastSampleDate = samples.isEmpty ? nil : Date()
  }

  private func draw(
    window: ArraySlice<VitalSample>,
    minValue: Double,
    maxValue: Double,
    windowStart: Double,
    size: CGSize,
    path: inout Path
  ) {
    let range = max(maxValue - minValue, .leastNonzeroMagnitude)
    let width = max(size.width - 1, 1)
    let height = size.height

    var moved = false
    for sample in window {
      let xNorm = min(max((sample.time - windowStart) / windowSeconds, 0), 1)
      let x = CGFloat(xNorm) * width
      let y = height - CGFloat((sample.value - minValue) / range) * height
      guard x.isFinite, y.isFinite else { continue }

      if moved {
        path.addLine(to: CGPoint(x: x, y: y))
      } else {
        path.move(to: CGPoint(x: x, y: y))
        moved = true
      }
    }
  }

  private struct PlotContext {
    let window: ArraySlice<VitalSample>
    let minValue: Double
    let maxValue: Double
    let windowStart: Double
  }
}
