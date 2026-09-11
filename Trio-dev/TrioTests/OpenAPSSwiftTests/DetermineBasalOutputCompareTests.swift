import Foundation
import Testing
@testable import Trio

@Suite("DetermineBasal output comparison: Swift vs JS", .serialized) struct DetermineBasalOutputCompareTests {
    let timeZoneForTests = TimeZoneForTests()

    @Test(
        "Compare determineBasal outputs: Swift vs JS",
        .enabled(if: ReplayTests.enabled)
    ) func compareDetermineBasal() async throws {
        let testingTimezone = ReplayTests.timezone
        let files = try await HttpFiles.listFiles()
        var results: [DetermineBasalComparisonEntry] = []

        for filePath in files {
            let algorithmComparison = try await HttpFiles.downloadFile(at: filePath)
            guard algorithmComparison.timezone == testingTimezone else { continue }
            guard let determineBasalInput = algorithmComparison.determineBasalInput else { continue }

            timeZoneForTests.setTimezone(identifier: algorithmComparison.timezone)

            var swiftUnits: Decimal?
            var swiftRate: Decimal?
            var swiftDuration: Decimal?
            var jsUnits: Decimal?
            var jsRate: Decimal?
            var jsDuration: Decimal?
            var entryError: String?

            // Swift
            do {
                let (swiftResult, _) = OpenAPSSwift.determineBasal(
                    glucose: determineBasalInput.glucose,
                    currentTemp: determineBasalInput.currentTemp,
                    iob: try JSONBridge.to(determineBasalInput.iob),
                    profile: try JSONBridge.to(determineBasalInput.profile),
                    autosens: try JSONBridge.to(determineBasalInput.autosens),
                    meal: try JSONBridge.to(determineBasalInput.meal),
                    microBolusAllowed: determineBasalInput.microBolusAllowed,
                    reservoir: determineBasalInput.reservoir ?? 0,
                    pumpHistory: determineBasalInput.pumpHistory,
                    preferences: determineBasalInput.preferences,
                    basalProfile: determineBasalInput.basalProfile,
                    trioCustomOrefVariables: determineBasalInput.trioCustomOrefVariables,
                    clock: determineBasalInput.clock
                )
                switch swiftResult {
                case let .success(rawJson):
                    let decoded: Determination = try JSONBridge.from(string: rawJson)
                    swiftUnits = decoded.units
                    swiftRate = decoded.rate
                    swiftDuration = decoded.duration
                case let .failure(err):
                    entryError = "Swift error: \(err.localizedDescription)"
                }
            } catch let swiftErr {
                entryError = "Swift exception: \(swiftErr.localizedDescription)"
            }

            // JS
            do {
                let openAps = OpenAPSFixed()
                let jsResult = try await openAps.determineBasalJavascript(
                    glucose: determineBasalInput.glucose,
                    currentTemp: determineBasalInput.currentTemp,
                    iob: try JSONBridge.to(determineBasalInput.iob),
                    profile: try JSONBridge.to(determineBasalInput.profile),
                    autosens: try JSONBridge.to(determineBasalInput.autosens),
                    meal: try JSONBridge.to(determineBasalInput.meal),
                    microBolusAllowed: determineBasalInput.microBolusAllowed,
                    reservoir: determineBasalInput.reservoir ?? 0,
                    pumpHistory: determineBasalInput.pumpHistory,
                    preferences: determineBasalInput.preferences,
                    basalProfile: determineBasalInput.basalProfile,
                    trioCustomOrefVariables: determineBasalInput.trioCustomOrefVariables,
                    clock: determineBasalInput.clock
                )
                switch jsResult {
                case let .success(rawJson):
                    let decoded: Determination = try JSONBridge.from(string: rawJson)
                    jsUnits = decoded.units
                    jsRate = decoded.rate
                    jsDuration = decoded.duration
                case let .failure(err):
                    let existing = entryError.map { $0 + "; " } ?? ""
                    entryError = existing + "JS error: \(err.localizedDescription)"
                }
            } catch let jsErr {
                let existing = entryError.map { $0 + "; " } ?? ""
                entryError = existing + "JS exception: \(jsErr.localizedDescription)"
            }

            results.append(DetermineBasalComparisonEntry(
                filePath: filePath,
                swiftUnits: swiftUnits,
                swiftRate: swiftRate,
                swiftDuration: swiftDuration,
                jsUnits: jsUnits,
                jsRate: jsRate,
                jsDuration: jsDuration,
                error: entryError
            ))

            timeZoneForTests.resetTimezone()
        }

        try OutputCompareUtils.writeResults(results, function: "determine_basal", timezone: testingTimezone)
    }
}
