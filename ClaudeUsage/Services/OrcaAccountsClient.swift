import Foundation

enum OrcaClientError: LocalizedError, Equatable {
    case launchFailed
    case timedOut
    case runtimeUnavailable(String?)

    var errorDescription: String? {
        switch self {
        case .launchFailed:
            return "Orca CLI를 실행할 수 없습니다"
        case .timedOut:
            return "Orca 응답 시간이 초과되었습니다"
        case .runtimeUnavailable(let message):
            guard let message, !message.isEmpty else {
                return "Orca가 실행 중이 아닙니다"
            }
            return message
        }
    }
}

enum OrcaAccountsClient {
    static let defaultTimeoutSeconds: UInt64 = 5

    static func executableURL() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return ExecutableLocator.find("orca", extraPaths: [
            "/opt/homebrew/bin/orca",
            "/usr/local/bin/orca",
            "\(home)/.local/bin/orca",
            // 심볼릭 링크가 없어도 앱 번들 안의 런처를 직접 실행할 수 있다.
            "/Applications/Orca.app/Contents/Resources/bin/orca",
            "\(home)/Applications/Orca.app/Contents/Resources/bin/orca",
        ])
    }

    /// Orca가 캐시해 둔 계정·사용량 스냅샷을 읽는다. 이 호출은 Orca의 갱신을
    /// 유발하지 않으므로 값의 나이는 스냅샷의 updatedAt으로 판단해야 한다.
    /// Orca가 꺼져 있을 때 앱이 Orca를 띄우면 안 되므로 `orca open`은 부르지 않는다.
    static func fetchSnapshot(
        using executableURL: URL,
        timeoutSeconds: UInt64 = defaultTimeoutSeconds
    ) async throws -> OrcaSnapshot {
        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = executableURL
        process.arguments = ["account", "list", "--json"]
        // stdin을 막아두지 않으면 CLI가 입력을 기다릴 수 있다.
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw OrcaClientError.launchFailed
        }

        let controller = ManagedProcess(process: process)

        return try await withTaskCancellationHandler {
            try await withThrowingTaskGroup(of: OrcaSnapshot.self) { group in
                group.addTask {
                    let data = try await readAll(from: outputPipe.fileHandleForReading)
                    return try decode(data)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                    controller.stop()
                    throw OrcaClientError.timedOut
                }

                do {
                    guard let snapshot = try await group.next() else {
                        throw OrcaClientError.runtimeUnavailable(nil)
                    }
                    controller.stop()
                    group.cancelAll()
                    return snapshot
                } catch {
                    controller.stop()
                    group.cancelAll()
                    throw error
                }
            }
        } onCancel: {
            controller.stop()
        }
    }

    static func decode(_ data: Data) throws -> OrcaSnapshot {
        guard !data.isEmpty else {
            throw OrcaClientError.runtimeUnavailable(nil)
        }
        guard let envelope = try? JSONDecoder().decode(OrcaEnvelope.self, from: data) else {
            // --json을 줬어도 런타임에 닿지 못하면 평문 오류가 올 수 있다.
            throw OrcaClientError.runtimeUnavailable(firstMeaningfulLine(in: data))
        }
        guard envelope.ok != false, let result = envelope.result else {
            throw OrcaClientError.runtimeUnavailable(envelope.error?.message)
        }
        return OrcaSnapshot(result: result)
    }

    private static func readAll(from handle: FileHandle) async throws -> Data {
        var lines = [String]()
        for try await line in handle.bytes.lines {
            try Task.checkCancellation()
            lines.append(line)
        }
        return Data(lines.joined(separator: "\n").utf8)
    }

    private static func firstMeaningfulLine(in data: Data) -> String? {
        let text = String(decoding: data, as: UTF8.self)
        guard let line = text
            .split(separator: "\n")
            .map({ $0.trimmingCharacters(in: .whitespaces) })
            .first(where: { !$0.isEmpty })
        else { return nil }
        return String(line.prefix(140))
    }
}
