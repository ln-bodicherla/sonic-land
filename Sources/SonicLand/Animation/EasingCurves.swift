import Foundation

/// Collection of easing functions for smooth animations.
enum EasingCurve: String, Codable {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    case spring

    /// Evaluate the easing function at time t (0...1).
    func evaluate(_ t: Double) -> Double {
        switch self {
        case .linear:
            return t
        case .easeIn:
            return t * t * t
        case .easeOut:
            return 1.0 - pow(1.0 - t, 3)
        case .easeInOut:
            if t < 0.5 {
                return 4 * t * t * t
            } else {
                return 1.0 - pow(-2 * t + 2, 3) / 2
            }
        case .spring:
            // Simple spring approximation
            let damping = 0.7
            let frequency = 3.5
            return 1.0 - exp(-damping * t * 10) * cos(frequency * t * .pi * 2)
        }
    }
}
