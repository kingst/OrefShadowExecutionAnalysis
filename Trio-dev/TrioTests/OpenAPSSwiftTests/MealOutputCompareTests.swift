import Foundation
import Testing
@testable import Trio

@Suite("Meal output comparison: Swift vs JS", .serialized) struct MealOutputCompareTests {
    let timeZoneForTests = TimeZoneForTests()

    @Test(
        "Compare meal outputs: Swift vs JS",
        .enabled(if: ReplayTests.enabled)
    ) func compareMeal() async throws {
        let testingTimezone = ReplayTests.timezone
        let files = try await HttpFiles.listFiles()
        var results: [MealComparisonEntry] = []

        for filePath in files {
            let algorithmComparison = try await HttpFiles.downloadFile(at: filePath)
            guard algorithmComparison.timezone == testingTimezone else { continue }
            guard let mealInputs = algorithmComparison.mealInput else { continue }

            if let mostRecentPumpEvent = mealInputs.pumpHistory.filter({ $0.isExternal != true }).first {
                if mostRecentPumpEvent.type == .pumpSuspend {
                    continue
                }
            }

            timeZoneForTests.setTimezone(identifier: algorithmComparison.timezone)

            var swiftCarbs: Decimal?
            var swiftMealCOB: Decimal?
            var jsCarbs: Decimal?
            var jsMealCOB: Decimal?
            var entryError: String?

            // Swift
            do {
                let (swiftResult, _) = OpenAPSSwift.meal(
                    pumphistory: mealInputs.pumpHistory,
                    profile: try JSONBridge.to(mealInputs.profile),
                    basalProfile: mealInputs.basalProfile,
                    clock: mealInputs.clock,
                    carbs: mealInputs.carbs,
                    glucose: mealInputs.glucose
                )
                switch swiftResult {
                case let .success(rawJson):
                    let decoded = try JSONBridge.computedCarbs(from: rawJson)
                    swiftCarbs = decoded?.carbs
                    swiftMealCOB = decoded?.mealCOB
                case let .failure(err):
                    entryError = "Swift error: \(err.localizedDescription)"
                }
            } catch let swiftErr {
                entryError = "Swift exception: \(swiftErr.localizedDescription)"
            }

            // JS
            do {
                let openAps = OpenAPSFixed()
                let jsResult = await openAps.mealJavascript(
                    pumphistory: mealInputs.pumpHistory,
                    profile: try JSONBridge.to(mealInputs.profile),
                    basalProfile: mealInputs.basalProfile,
                    clock: mealInputs.clock,
                    carbs: mealInputs.carbs,
                    glucose: mealInputs.glucose
                )
                switch jsResult {
                case let .success(rawJson):
                    let decoded = try JSONBridge.computedCarbs(from: rawJson)
                    jsCarbs = decoded?.carbs
                    jsMealCOB = decoded?.mealCOB
                case let .failure(err):
                    let existing = entryError.map { $0 + "; " } ?? ""
                    entryError = existing + "JS error: \(err.localizedDescription)"
                }
            } catch let jsErr {
                let existing = entryError.map { $0 + "; " } ?? ""
                entryError = existing + "JS exception: \(jsErr.localizedDescription)"
            }

            results.append(MealComparisonEntry(
                filePath: filePath,
                swiftCarbs: swiftCarbs,
                swiftMealCOB: swiftMealCOB,
                jsCarbs: jsCarbs,
                jsMealCOB: jsMealCOB,
                error: entryError
            ))

            timeZoneForTests.resetTimezone()
        }

        try OutputCompareUtils.writeResults(results, function: "meal", timezone: testingTimezone)
    }
}
