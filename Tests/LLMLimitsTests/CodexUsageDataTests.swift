import XCTest
@testable import LLMLimits

final class CodexUsageDataTests: XCTestCase {
    func testClientReadsRateLimitsFromAppServerProtocol() async throws {
        let executable = FileManager.default.temporaryDirectory
            .appendingPathComponent("llm-limits-fake-codex-\(UUID().uuidString)")
        let script = #"""
        #!/bin/sh
        response='{"id":2,"result":{"rateLimits":{"limitId":"codex","primary":{"usedPercent":23,"windowDurationMins":300,"resetsAt":1788537442},"secondary":null,"credits":null,"planType":"plus"},"rateLimitsByLimitId":null}}'
        while IFS= read -r line; do
          case "$line" in
            *account/rateLimits/read*) printf '%s\n' "$response" ;;
          esac
        done
        """#

        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        defer { try? FileManager.default.removeItem(at: executable) }

        let usage = try await CodexUsageClient.fetchUsage(using: executable)

        XCTAssertEqual(usage.displayLimits.map(\.metric.utilization), [23])
        XCTAssertEqual(usage.representativeUtilization, 23)
    }

    func testDecodesDefaultAndModelSpecificLimitsWithoutDuplicates() throws {
        let json = #"""
        {
          "rateLimits": {
            "limitId": "codex",
            "limitName": null,
            "primary": {
              "usedPercent": 42,
              "windowDurationMins": 10080,
              "resetsAt": 1789123178
            },
            "secondary": null,
            "credits": {
              "hasCredits": false,
              "unlimited": false,
              "balance": "0"
            },
            "planType": "plus"
          },
          "rateLimitsByLimitId": {
            "codex": {
              "limitId": "codex",
              "limitName": null,
              "primary": {
                "usedPercent": 42,
                "windowDurationMins": 10080,
                "resetsAt": 1789123178
              },
              "secondary": null,
              "credits": {
                "hasCredits": false,
                "unlimited": false,
                "balance": "0"
              },
              "planType": "plus"
            },
            "codex_spark": {
              "limitId": "codex_spark",
              "limitName": "GPT-5.3-Codex-Spark",
              "primary": {
                "usedPercent": 18,
                "windowDurationMins": 300,
                "resetsAt": 1788537442
              },
              "secondary": {
                "usedPercent": 7,
                "windowDurationMins": 10080,
                "resetsAt": 1789124242
              },
              "credits": null,
              "planType": "plus"
            }
          }
        }
        """#

        let usage = try JSONDecoder().decode(CodexUsageData.self, from: Data(json.utf8))

        XCTAssertEqual(
            usage.displayLimits.map(\.title),
            ["주간", "GPT-5.3-Codex-Spark · 5시간 세션", "GPT-5.3-Codex-Spark · 주간"]
        )
        XCTAssertEqual(usage.displayLimits.map(\.metric.utilization), [42, 18, 7])
        XCTAssertEqual(usage.representativeUtilization, 18)
        XCTAssertEqual(usage.maxUtilization, 42)
        XCTAssertEqual(usage.planLabel, "PLUS")
    }

    func testFormatsUncommonWindowDurations() throws {
        let threeDay = CodexRateLimitWindow(
            usedPercent: 5,
            windowDurationMins: 4_320,
            resetsAt: nil
        )
        let ninetyMinutes = CodexRateLimitWindow(
            usedPercent: 10,
            windowDurationMins: 90,
            resetsAt: nil
        )

        XCTAssertEqual(threeDay.displayName, "3일")
        XCTAssertEqual(ninetyMinutes.displayName, "90분")
    }
}
