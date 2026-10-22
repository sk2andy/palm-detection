import Foundation

public struct TouchPoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public var isValid: Bool {
        x.isFinite && y.isFinite && (0...1).contains(x) && (0...1).contains(y)
    }

    public func distance(to other: TouchPoint) -> Double {
        hypot(x - other.x, y - other.y)
    }
}

/// Normalized coordinates, with the origin at the lower-left of the trackpad.
public struct TapArea: Codable, Equatable, Sendable {
    public var minX: Double
    public var minY: Double
    public var maxX: Double
    public var maxY: Double

    public static let `default` = TapArea(minX: 0.12, minY: 0.12, maxX: 0.88, maxY: 0.88)

    public init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }

    /// Repair malformed persisted or intermediate editor values to a nonempty rectangle.
    public var sanitized: TapArea {
        guard [minX, minY, maxX, maxY].allSatisfy(\.isFinite) else { return .default }
        let left = min(0.98, max(0, min(minX, maxX)))
        let bottom = min(0.98, max(0, min(minY, maxY)))
        return TapArea(
            minX: left,
            minY: bottom,
            maxX: min(1, max(left + 0.02, max(minX, maxX))),
            maxY: min(1, max(bottom + 0.02, max(minY, maxY)))
        )
    }

    public func contains(_ point: TouchPoint) -> Bool {
        guard point.isValid else { return false }
        let area = sanitized
        return (area.minX...area.maxX).contains(point.x)
            && (area.minY...area.maxY).contains(point.y)
    }
}

public struct TouchContact: Equatable, Sendable {
    public let id: Int
    public let position: TouchPoint
    public let size: Double

    public init(id: Int, position: TouchPoint, size: Double) {
        self.id = id
        self.position = position
        self.size = size
    }

    public var isValid: Bool {
        position.isValid && size.isFinite && size >= 0
    }
}
