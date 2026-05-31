import Foundation
import SwiftUI

enum HRZone: Int, CaseIterable, Identifiable {
    case z1 = 1, z2, z3, z4, z5

    var id: Int { rawValue }

    var name: String { "Zone \(rawValue)" }

    var shortName: String { "Z\(rawValue)" }

    // % of max HR: lower bound (inclusive) to upper bound (exclusive)
    var range: ClosedRange<Double> {
        switch self {
        case .z1: return 0.50 ... 0.60
        case .z2: return 0.60 ... 0.70
        case .z3: return 0.70 ... 0.80
        case .z4: return 0.80 ... 0.90
        case .z5: return 0.90 ... 1.10
        }
    }

    var color: Color {
        switch self {
        case .z1: return .blue
        case .z2: return .green
        case .z3: return .yellow
        case .z4: return .orange
        case .z5: return .red
        }
    }

    static func zone(for bpm: Double, maxHR: Double) -> HRZone? {
        let pct = bpm / maxHR
        return allCases.first { $0.range.contains(pct) }
    }
}

extension HRZone {
    func bpmRange(maxHR: Double) -> ClosedRange<Double> {
        (range.lowerBound * maxHR) ... (range.upperBound * maxHR)
    }
}
