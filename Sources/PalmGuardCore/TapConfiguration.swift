import Foundation

public struct TapConfiguration: Codable, Equatable, Sendable {
    public var area: TapArea
    public var maximumDuration: Double
    public var maximumMovement: Double
    public var maximumSize: Double
    public var minimumDuration: Double
    public var maximumFingerLandingInterval: Double

    public init(
        area: TapArea = .default,
        maximumDuration: Double = 0.22,
        maximumMovement: Double = 0.025,
        maximumSize: Double = 1.8,
        minimumDuration: Double = 0.025,
        maximumFingerLandingInterval: Double = 0.08
    ) {
        self.area = area
        self.maximumDuration = maximumDuration
        self.maximumMovement = maximumMovement
        self.maximumSize = maximumSize
        self.minimumDuration = minimumDuration
        self.maximumFingerLandingInterval = maximumFingerLandingInterval
    }

    public var sanitized: TapConfiguration {
        let duration = Self.clamp(maximumDuration, to: 0.01...1, fallback: 0.22)
        return TapConfiguration(
            area: area.sanitized,
            maximumDuration: duration,
            maximumMovement: Self.clamp(maximumMovement, to: 0.001...1, fallback: 0.025),
            maximumSize: Self.clamp(maximumSize, to: 0.01...10, fallback: 1.8),
            minimumDuration: Self.clamp(minimumDuration, to: 0.001...duration, fallback: min(0.025, duration)),
            maximumFingerLandingInterval: Self.clamp(
                maximumFingerLandingInterval, to: 0.001...duration, fallback: min(0.08, duration)
            )
        )
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>, fallback: Double) -> Double {
        guard value.isFinite else { return fallback }
        return min(range.upperBound, max(range.lowerBound, value))
    }
}
