import XCTest
@testable import LLMLimits

final class UsageDataRowsTests: XCTestCase {
    func testDeduplicatesTheSameWeeklyModelLimit() throws {
        // seven_day_sonnet과 limits[weekly_scoped]의 Sonnet은 같은 한도다.
        let json = """
        {
          "seven_day_sonnet": { "utilization": 12, "resets_at": null },
          "limits": [
            {
              "kind": "weekly_scoped",
              "percent": 99,
              "resets_at": null,
              "scope": { "model": { "display_name": "Sonnet" } }
            }
          ]
        }
        """
        let usage = try JSONDecoder().decode(UsageData.self, from: Data(json.utf8))

        XCTAssertEqual(usage.rows.map(\.id), [UsageRowID.weeklyModel("Sonnet")])
        XCTAssertEqual(usage.rows.map(\.metric.utilization), [12])
    }

    func testParsesTimestampsWithAndWithoutFractionalSeconds() throws {
        let json = """
        {
          "five_hour": { "utilization": 1, "resets_at": "2026-09-14T16:50:00.973Z" },
          "seven_day": { "utilization": 2, "resets_at": "2026-09-19T11:00:00Z" }
        }
        """
        let usage = try JSONDecoder().decode(UsageData.self, from: Data(json.utf8))

        XCTAssertEqual(usage.fiveHour?.resetsAt, Date(timeIntervalSince1970: 1_789_404_600.973))
        XCTAssertEqual(usage.sevenDay?.resetsAt, Date(timeIntervalSince1970: 1_789_815_600))
    }

    func testSkipsMissingWindowsInsteadOfShowingPlaceholders() throws {
        let usage = try JSONDecoder().decode(UsageData.self, from: Data("{}".utf8))

        XCTAssertTrue(usage.rows.isEmpty)
        XCTAssertEqual(usage.maxUtilization, 0)
    }
}
