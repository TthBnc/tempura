import Foundation
import Testing
@testable import TempuraCore

@Test("Temperature history keeps only the retention window")
func keepsOnlyRetentionWindow() {
    let now = Date(timeIntervalSinceReferenceDate: 1_000)
    var history = TemperatureHistory(retention: 60)

    history.record(celsius: 42, date: now.addingTimeInterval(-61))
    history.record(celsius: 48, date: now.addingTimeInterval(-60))
    history.record(celsius: 54, date: now)
    history.prune(now: now)

    #expect(history.samples.map(\.celsius) == [48, 54])
}

@Test("Temperature history creates padded dynamic range")
func createsPaddedDynamicRange() throws {
    let now = Date(timeIntervalSinceReferenceDate: 1_000)
    var history = TemperatureHistory(retention: 60)

    history.record(celsius: 58, date: now)
    history.record(celsius: 64, date: now.addingTimeInterval(5))

    let range = try #require(history.dynamicRange())
    #expect(range.lowerBound == 55)
    #expect(range.upperBound == 67)
}

@Test("Temperature history enforces minimum range span")
func enforcesMinimumRangeSpan() throws {
    let now = Date(timeIntervalSinceReferenceDate: 1_000)
    var history = TemperatureHistory(retention: 60)

    history.record(celsius: 60, date: now)
    history.record(celsius: 61, date: now.addingTimeInterval(5))

    let range = try #require(history.dynamicRange())
    #expect(range.lowerBound == 56.5)
    #expect(range.upperBound == 64.5)
}

@Test("Temperature history summarizes average peak and low")
func summarizesAveragePeakAndLow() throws {
    let now = Date(timeIntervalSinceReferenceDate: 1_000)
    var history = TemperatureHistory(retention: 60)

    history.record(celsius: 60, date: now)
    history.record(celsius: 66, date: now.addingTimeInterval(5))
    history.record(celsius: 72, date: now.addingTimeInterval(10))

    let stats = try #require(history.stats())
    #expect(stats.averageCelsius == 66)
    #expect(stats.peakCelsius == 72)
    #expect(stats.lowCelsius == 60)
    #expect(stats.sampleCount == 3)
}
