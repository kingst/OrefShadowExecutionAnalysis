import Foundation
import Testing
@testable import Trio

@Suite("IoB output comparison: Swift vs JS", .serialized) struct IobOutputCompareTests {
    let timeZoneForTests = TimeZoneForTests()

    @Test(
        "Compare IoB outputs: Swift vs JS",
        .enabled(if: ReplayTests.enabled)
    ) func compareIob() async throws {
        let testingTimezone = ReplayTests.timezone
        let files = try await HttpFiles.listFiles()
        var results: [IobComparisonEntry] = []

        for filePath in files {
            let algorithmComparison = try await HttpFiles.downloadFile(at: filePath)
            guard algorithmComparison.timezone == testingTimezone else { continue }
            guard let iobInputs = algorithmComparison.iobInput else { continue }

            if IobJsonTests.pumpIsSuspended(history: iobInputs.history) {
                continue
            }

            timeZoneForTests.setTimezone(identifier: algorithmComparison.timezone)

            var swiftIob: Decimal?
            var swiftActivity: Decimal?
            var jsIob: Decimal?
            var jsActivity: Decimal?
            var entryError: String?

            // Swift
            do {
                let (swiftResult, _) = OpenAPSSwift.iob(
                    pumphistory: iobInputs.history,
                    profile: try JSONBridge.to(iobInputs.profile),
                    clock: iobInputs.clock,
                    autosens: try JSONBridge.to(iobInputs.autosens)
                )
                switch swiftResult {
                case let .success(rawJson):
                    let decoded = try JSONBridge.iobResult(from: rawJson)
                    swiftIob = decoded.first?.iob
                    swiftActivity = decoded.first?.activity
                case let .failure(err):
                    entryError = "Swift error: \(err.localizedDescription)"
                }
            } catch let swiftErr {
                entryError = "Swift exception: \(swiftErr.localizedDescription)"
            }

            // JS
            do {
                let openAps = OpenAPSFixed()
                let jsResult = await openAps.iobJavascript(
                    pumphistory: iobInputs.history,
                    profile: try JSONBridge.to(iobInputs.profile),
                    clock: iobInputs.clock,
                    autosens: try JSONBridge.to(iobInputs.autosens)
                )
                switch jsResult {
                case let .success(rawJson):
                    let decoded = try JSONBridge.iobResult(from: rawJson)
                    jsIob = decoded.first?.iob
                    jsActivity = decoded.first?.activity
                case let .failure(err):
                    let existing = entryError.map { $0 + "; " } ?? ""
                    entryError = existing + "JS error: \(err.localizedDescription)"
                }
            } catch let jsErr {
                let existing = entryError.map { $0 + "; " } ?? ""
                entryError = existing + "JS exception: \(jsErr.localizedDescription)"
            }

            results.append(IobComparisonEntry(
                filePath: filePath,
                swiftIob: swiftIob,
                swiftActivity: swiftActivity,
                jsIob: jsIob,
                jsActivity: jsActivity,
                error: entryError
            ))

            timeZoneForTests.resetTimezone()
        }

        try OutputCompareUtils.writeResults(results, function: "iob", timezone: testingTimezone)
    }
}
