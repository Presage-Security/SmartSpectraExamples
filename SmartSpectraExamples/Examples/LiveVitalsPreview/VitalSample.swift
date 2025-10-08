//
//  VitalSample.swift
//  SmartSpectraExamples
//
//  Copyright (c) 2025 Presage Technologies. All rights reserved.
//

import Foundation

/// Lightweight data point used to render vitals traces over time.
struct VitalSample: Equatable {
  let time: Double
  let value: Double
}
