import Foundation
@testable import Trio

struct IobComparisonEntry: Codable {
    let filePath: String
    let swiftIob: Decimal?
    let swiftActivity: Decimal?
    let jsIob: Decimal?
    let jsActivity: Decimal?
    let error: String?
}

struct MealComparisonEntry: Codable {
    let filePath: String
    let swiftCarbs: Decimal?
    let swiftMealCOB: Decimal?
    let jsCarbs: Decimal?
    let jsMealCOB: Decimal?
    let error: String?
}

struct AutosensComparisonEntry: Codable {
    let filePath: String
    let swiftRatio: Decimal?
    let jsRatio: Decimal?
    let error: String?
}

struct DetermineBasalComparisonEntry: Codable {
    let filePath: String
    let swiftUnits: Decimal?
    let swiftRate: Decimal?
    let swiftDuration: Decimal?
    let jsUnits: Decimal?
    let jsRate: Decimal?
    let jsDuration: Decimal?
    let error: String?
}

enum OutputCompareUtils {
    static func writeResults<T: Encodable>(_ results: [T], function: String, timezone: String) throws {
        let safeTimezone = timezone.replacingOccurrences(of: "/", with: "_")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(results)
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("output_compare_\(function)_\(safeTimezone).json")
        try data.write(to: url)
        print("Output comparison written to: \(url.path)")
    }
}
