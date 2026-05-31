import Foundation
import SwiftUI

enum HRZone: Int, CaseIterable, Identifiable {
    case z1 = 1, z2, z3, z4, z5

    var id: Int { rawValue }

    var name: String { "Zone \(rawValue)" }

    var shortName: String { "Z\(rawValue)" }

    // % of max HR lower bound (inclusive); zone 5 is open-ended (≥ 90%)
    var lowerBound: Double {
        switch self {
        case .z1: return 0.50
        case .z2: return 0.60
        case .z3: return 0.70
        case .z4: return 0.80
        case .z5: return 0.90
        }
    }

    var upperBound: Double? {
        switch self {
        case .z1: return 0.60
        case .z2: return 0.70
        case .z3: return 0.80
        case .z4: return 0.90
        case .z5: return nil  // open-ended
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
        return allCases.first { zone in
            guard pct >= zone.lowerBound else { return false }
            if let upper = zone.upperBound { return pct < upper }
            return true  // zone 5: no upper bound
        }
    }
}

extension HRZone {
    func bpmRange(maxHR: Double) -> ClosedRange<Double> {
        let lo = lowerBound * maxHR
        let hi = (upperBound ?? 1.0) * maxHR  // display zone 5 as up to max HR
        return lo ... hi
    }
}
