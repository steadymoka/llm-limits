import XCTest
@testable import LLMLimits

final class OrcaSnapshotTests: XCTestCase {
    /// `orca account list --json`의 실제 응답 모양.
    private func snapshotJSON(activeProvenance: String?) -> String {
        let provenance = activeProvenance.map { "\"\($0)\"" } ?? "null"
        return """
        {
          "id": "req-1",
          "ok": true,
          "result": {
            "claude": {
              "accounts": [
                {
                  "id": "acct-a",
                  "email": "first@example.com",
                  "organizationUuid": "org-a",
                  "organizationName": "First Org",
                  "authMethod": "subscription-oauth"
                },
                {
                  "id": "acct-b",
                  "email": "second@example.com",
                  "organizationUuid": "org-b",
                  "organizationName": "Second Org",
                  "authMethod": "subscription-oauth"
                }
              ],
              "activeAccountId": "acct-b"
            },
            "codex": {
              "accounts": [],
              "activeAccountId": null,
              "systemDefault": { "hasAuth": true, "email": "codex@example.com", "providerAccountId": "codex-1" }
            },
            "rateLimits": {
              "claude": {
                "provider": "claude",
                "session": { "usedPercent": 16, "windowMinutes": 300, "resetsAt": 1789372200973 },
                "weekly": { "usedPercent": 2, "windowMinutes": 10080, "resetsAt": 1789696800973 },
                "fableWeekly": { "usedPercent": 4, "windowMinutes": 10080, "resetsAt": 1789696800973 },
                "updatedAt": 1789354765112,
                "status": "ok",
                "error": null,
                "usageMetadata": { "source": "oauth", "authProvenance": \(provenance) }
              },
              "inactiveClaudeAccounts": [
                {
                  "accountId": "acct-a",
                  "rateLimits": {
                    "provider": "claude",
                    "session": { "usedPercent": 1, "windowMinutes": 300, "resetsAt": 1789369800080 },
                    "weekly": { "usedPercent": 96, "windowMinutes": 10080, "resetsAt": 1789488000080 },
                    "fableWeekly": { "usedPercent": 73, "windowMinutes": 10080, "resetsAt": 1789488000080 },
                    "updatedAt": 1789354495401,
                    "status": "ok",
                    "error": null
                  },
                  "updatedAt": 1789354495401,
                  "isFetching": true
                }
              ],
              "inactiveCodexAccounts": []
            }
          }
        }
        """
    }

    func testBuildsOneEntryPerManagedAccountWithActiveFirst() throws {
        let snapshot = try OrcaAccountsClient.decode(Data(snapshotJSON(activeProvenance: "managed:acct-b").utf8))

        XCTAssertEqual(snapshot.claude.map(\.label), ["second@example.com", "first@example.com"])
        XCTAssertEqual(snapshot.claude.map(\.isActive), [true, false])
        XCTAssertEqual(snapshot.claude.map(\.orgID), ["org-b", "org-a"])
        XCTAssertEqual(snapshot.codexSystemDefaultLabel, "codex@example.com")
    }

    func testMapsBothActiveAndInactiveUsageOntoRows() throws {
        let snapshot = try OrcaAccountsClient.decode(Data(snapshotJSON(activeProvenance: "managed:acct-b").utf8))
        let active = try XCTUnwrap(snapshot.claude.first)
        let inactive = try XCTUnwrap(snapshot.claude.last)

        XCTAssertEqual(active.rows.map(\.id), [
            UsageRowID.fiveHour,
            UsageRowID.sevenDay,
            UsageRowID.weeklyModel("Fable"),
        ])
        XCTAssertEqual(active.rows.map(\.metric.utilization), [16, 2, 4])
        // 비활성 계정도 같은 구조로 내려온다 — 이게 다계정 표시의 근거다.
        XCTAssertEqual(inactive.rows.map(\.metric.utilization), [1, 96, 73])
        XCTAssertTrue(inactive.isFetching)
    }

    func testConvertsMillisecondTimestamps() throws {
        let snapshot = try OrcaAccountsClient.decode(Data(snapshotJSON(activeProvenance: "managed:acct-b").utf8))
        let active = try XCTUnwrap(snapshot.claude.first)

        XCTAssertEqual(active.updatedAt, Date(timeIntervalSince1970: 1_789_354_765.112))
        XCTAssertEqual(active.rows.first?.metric.resetsAt, Date(timeIntervalSince1970: 1_789_372_200.973))
    }

    func testActiveUsageIsAttributedByProvenanceNotByPosition() throws {
        // provenance가 비활성 계정을 가리키면 그 계정의 사용량이다.
        let snapshot = try OrcaAccountsClient.decode(Data(snapshotJSON(activeProvenance: "managed:acct-a").utf8))
        let active = try XCTUnwrap(snapshot.claude.first { $0.isActive })
        let other = try XCTUnwrap(snapshot.claude.first { !$0.isActive })

        XCTAssertEqual(active.label, "second@example.com")
        XCTAssertTrue(active.rows.isEmpty)
        // acct-a는 inactive 항목이 먼저 채운 뒤 활성 사용량으로 덮인다.
        XCTAssertEqual(other.rows.map(\.metric.utilization), [16, 2, 4])
    }

    func testNonManagedProvenanceIsNotCreditedToAnyAccount() throws {
        // 시스템 기본 로그인의 사용량을 활성 관리 계정에 붙이면 거짓말이 된다.
        let snapshot = try OrcaAccountsClient.decode(Data(snapshotJSON(activeProvenance: "system").utf8))
        let active = try XCTUnwrap(snapshot.claude.first { $0.isActive })

        XCTAssertTrue(active.rows.isEmpty)
    }

    func testMissingProvenanceFallsBackToActiveAccount() throws {
        let snapshot = try OrcaAccountsClient.decode(Data(snapshotJSON(activeProvenance: nil).utf8))
        let active = try XCTUnwrap(snapshot.claude.first { $0.isActive })

        XCTAssertEqual(active.rows.map(\.metric.utilization), [16, 2, 4])
    }

    func testTreatsNonJSONOutputAsUnavailableRuntime() throws {
        let data = Data("Unable to reach the Orca runtime. Run `orca open` first.\n".utf8)

        XCTAssertThrowsError(try OrcaAccountsClient.decode(data)) { error in
            XCTAssertEqual(
                error as? OrcaClientError,
                .runtimeUnavailable("Unable to reach the Orca runtime. Run `orca open` first.")
            )
        }
    }

    func testTreatsFailedEnvelopeAsUnavailableRuntime() throws {
        let data = Data(#"{"ok":false,"error":{"message":"runtime not reachable"}}"#.utf8)

        XCTAssertThrowsError(try OrcaAccountsClient.decode(data)) { error in
            XCTAssertEqual(error as? OrcaClientError, .runtimeUnavailable("runtime not reachable"))
        }
    }

    func testReadsSnapshotThroughTheCLIProcess() async throws {
        let executable = FileManager.default.temporaryDirectory
            .appendingPathComponent("llm-limits-fake-orca-\(UUID().uuidString)")
        let payload = snapshotJSON(activeProvenance: "managed:acct-b")
            .replacingOccurrences(of: "'", with: "")
        let script = """
        #!/bin/sh
        cat <<'JSON'
        \(payload)
        JSON
        """

        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        defer { try? FileManager.default.removeItem(at: executable) }

        let snapshot = try await OrcaAccountsClient.fetchSnapshot(using: executable)

        XCTAssertEqual(snapshot.claude.count, 2)
        XCTAssertEqual(snapshot.claude.first?.label, "second@example.com")
    }
}

extension OrcaSnapshotTests {
    /// Orca가 응답하지 않아도 5분마다 도는 폴링이 멈춰서는 안 된다.
    func testTimesOutInsteadOfHangingOnAnUnresponsiveCLI() async throws {
        let executable = FileManager.default.temporaryDirectory
            .appendingPathComponent("llm-limits-hanging-orca-\(UUID().uuidString)")
        let script = """
        #!/bin/sh
        sleep 30
        """

        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        defer { try? FileManager.default.removeItem(at: executable) }

        do {
            _ = try await OrcaAccountsClient.fetchSnapshot(using: executable, timeoutSeconds: 1)
            XCTFail("타임아웃이 걸려야 한다")
        } catch {
            XCTAssertEqual(error as? OrcaClientError, .timedOut)
        }
    }
}
