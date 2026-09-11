import Foundation
import Testing
@testable import Trio

@Suite("Autosens output comparison: Swift vs JS", .serialized) struct AutosensOutputCompareTests {
    let timeZoneForTests = TimeZoneForTests()

    @Test(
        "Compare autosens outputs: Swift vs JS",
        .enabled(if: ReplayTests.enabled)
    ) func compareAutosens() async throws {
        let testingTimezone = ReplayTests.timezone
        let files = try await HttpFiles.listFiles()
        var results: [AutosensComparisonEntry] = []

        for filePath in files {
            let algorithmComparison = try await HttpFiles.downloadFile(at: filePath)
            guard algorithmComparison.timezone == testingTimezone else { continue }
            guard let autosensInputs = algorithmComparison.autosensInput else { continue }

            timeZoneForTests.setTimezone(identifier: algorithmComparison.timezone)

            var swiftRatio: Decimal?
            var jsRatio: Decimal?
            var entryError: String?

            // Swift
            do {
                let (swiftResult, _) = OpenAPSSwift.autosense(
                    glucose: autosensInputs.glucose,
                    pumpHistory: autosensInputs.history,
                    basalProfile: autosensInputs.basalProfile,
                    profile: try JSONBridge.to(autosensInputs.profile),
                    carbs: autosensInputs.carbs,
                    tempTargets: autosensInputs.tempTargets,
                    clock: autosensInputs.clock
                )
                switch swiftResult {
                case let .success(rawJson):
                    let decoded = try JSONBridge.autosens(from: rawJson)
                    swiftRatio = decoded?.ratio
                case let .failure(err):
                    entryError = "Swift error: \(err.localizedDescription)"
                }
            } catch let swiftErr {
                entryError = "Swift exception: \(swiftErr.localizedDescription)"
            }

            // JS
            do {
                let openAps = OpenAPSFixed()
                let jsResult = await openAps.autosenseJavascript(
                    glucose: autosensInputs.glucose,
                    pumpHistory: autosensInputs.history,
                    basalprofile: autosensInputs.basalProfile,
                    profile: try JSONBridge.to(autosensInputs.profile),
                    carbs: autosensInputs.carbs,
                    temptargets: autosensInputs.tempTargets,
                    clock: autosensInputs.clock,
                    prepareFile: OpenAPSFixed.prepare
                )
                switch jsResult {
                case let .success(rawJson):
                    let decoded = try JSONBridge.autosens(from: rawJson)
                    jsRatio = decoded?.ratio
                case let .failure(err):
                    let existing = entryError.map { $0 + "; " } ?? ""
                    entryError = existing + "JS error: \(err.localizedDescription)"
                }
            } catch let jsErr {
                let existing = entryError.map { $0 + "; " } ?? ""
                entryError = existing + "JS exception: \(jsErr.localizedDescription)"
            }

            results.append(AutosensComparisonEntry(
                filePath: filePath,
                swiftRatio: swiftRatio,
                jsRatio: jsRatio,
                error: entryError
            ))

            timeZoneForTests.resetTimezone()
        }

        try OutputCompareUtils.writeResults(results, function: "autosens", timezone: testingTimezone)
    }
}
