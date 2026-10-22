import Foundation
import Testing

@testable import PalmGuardCore

@Suite("Persisted configuration and normalized geometry")
struct ConfigurationTests {
    @Test func repairsReversedAndOutOfBoundsArea() {
        let area = TapArea(minX: 1.4, minY: 0.8, maxX: -0.2, maxY: 0.3).sanitized
        #expect(area == TapArea(minX: 0, minY: 0.3, maxX: 1, maxY: 0.8))
    }

    @Test func emptyAreaGetsMinimumSize() {
        let area = TapArea(minX: 1, minY: -1, maxX: 1, maxY: -1).sanitized
        #expect(area.minX == 0.98)
        #expect(area.maxX == 1)
        #expect(area.minY == 0)
        #expect(area.maxY == 0.02)
    }

    @Test func invalidAreaUsesDefault() {
        #expect(TapArea(minX: .nan, minY: 0, maxX: 1, maxY: 1).sanitized == .default)
    }

    @Test func rectangleIncludesEdgesButRejectsNonfiniteCoordinates() {
        let area = TapArea.default
        #expect(area.contains(TouchPoint(x: area.minX, y: area.maxY)))
        #expect(!area.contains(TouchPoint(x: .nan, y: 0.5)))
        #expect(!area.contains(TouchPoint(x: -1, y: 0.5)))
    }

    @Test func sanitizesAllThresholds() {
        let configuration = TapConfiguration(
            maximumDuration: -1,
            maximumMovement: .nan,
            maximumSize: .infinity,
            minimumDuration: 100,
            maximumFingerLandingInterval: 100
        ).sanitized
        #expect(configuration.maximumDuration == 0.01)
        #expect(configuration.minimumDuration == 0.01)
        #expect(configuration.maximumFingerLandingInterval == 0.01)
        #expect(configuration.maximumMovement == 0.025)
        #expect(configuration.maximumSize == 1.8)
    }

    @Test func configurationRoundTripsThroughJSON() throws {
        let configuration = TapConfiguration(area: TapArea(minX: 0.2, minY: 0.1, maxX: 0.8, maxY: 0.9))
        let data = try JSONEncoder().encode(configuration)
        #expect(try JSONDecoder().decode(TapConfiguration.self, from: data) == configuration)
    }
}
