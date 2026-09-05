import Foundation

enum CodexUsageClientError: LocalizedError {
    case timedOut
    case unavailable
    case server(String)
    case launchFailed

    var errorDescription: String? {
        switch self {
        case .timedOut:
            return "Codex 응답 시간이 초과되었습니다"
        case .unavailable:
            return "Codex 사용량 응답을 확인할 수 없습니다"
        case .server(let message):
            let normalized = message.lowercased()
            if normalized.contains("not logged in") || normalized.contains("login required") {
                return "Codex에 ChatGPT 로그인이 필요합니다"
            }
            if normalized.contains("api key") {
                return "ChatGPT 로그인 사용량만 표시할 수 있습니다"
            }
            return "Codex 사용량을 불러오지 못했습니다"
        case .launchFailed:
            return "Codex CLI를 실행할 수 없습니다"
        }
    }
}

enum CodexUsageClient {
    private static let responseId = 2
    private static let timeoutSeconds: UInt64 = 12

    static func executableURL() -> URL? {
        let fileManager = FileManager.default
        let environment = ProcessInfo.processInfo.environment
        let home = fileManager.homeDirectoryForCurrentUser.path

        var paths = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map { String($0) + "/codex" }

        paths.append(contentsOf: [
            "\(home)/.local/bin/codex",
            "\(home)/.volta/bin/codex",
            "\(home)/.bun/bin/codex",
            "\(home)/.npm-global/bin/codex",
            "\(home)/.asdf/shims/codex",
            "\(home)/.nodenv/shims/codex",
            "\(home)/.local/share/mise/shims/codex",
            "\(home)/.fnm/current/bin/codex",
            "\(home)/Library/Application Support/fnm/aliases/default/bin/codex",
            "\(home)/Library/pnpm/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "\(home)/Applications/Codex.app/Contents/Resources/codex",
        ])

        let nvmVersionsPath = "\(home)/.nvm/versions/node"
        if let versions = try? fileManager.contentsOfDirectory(atPath: nvmVersionsPath) {
            paths.append(contentsOf: versions
                .sorted { $0.compare($1, options: .numeric) == .orderedDescending }
                .map { "\(nvmVersionsPath)/\($0)/bin/codex" })
        }

        for path in paths {
            if fileManager.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    static func fetchUsage(using executableURL: URL) async throws -> CodexUsageData {
        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()

        process.executableURL = executableURL
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw CodexUsageClientError.launchFailed
        }

        let payload = """
        {"id":1,"method":"initialize","params":{"clientInfo":{"name":"llm-limits","title":"LLM Limits","version":"1.1.0"},"capabilities":{"experimentalApi":true}}}
        {"method":"initialized"}
        {"id":\(responseId),"method":"account/rateLimits/read"}

        """

        do {
            try inputPipe.fileHandleForWriting.write(contentsOf: Data(payload.utf8))
        } catch {
            if process.isRunning { process.terminate() }
            throw CodexUsageClientError.launchFailed
        }

        let processController = CodexProcessController(
            process: process,
            input: inputPipe.fileHandleForWriting
        )

        return try await withTaskCancellationHandler {
            try await withThrowingTaskGroup(of: CodexUsageData.self) { group in
                group.addTask {
                    try await readUsageResponse(from: outputPipe.fileHandleForReading)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                    processController.stop()
                    throw CodexUsageClientError.timedOut
                }

                do {
                    guard let usage = try await group.next() else {
                        throw CodexUsageClientError.unavailable
                    }
                    processController.stop()
                    group.cancelAll()
                    return usage
                } catch {
                    processController.stop()
                    group.cancelAll()
                    throw error
                }
            }
        } onCancel: {
            processController.stop()
        }
    }

    private static func readUsageResponse(from handle: FileHandle) async throws -> CodexUsageData {
        for try await line in handle.bytes.lines {
            try Task.checkCancellation()
            guard let data = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (object["id"] as? NSNumber)?.intValue == responseId else {
                continue
            }

            if let error = object["error"] as? [String: Any] {
                let message = error["message"] as? String ?? "Unknown Codex app-server error"
                throw CodexUsageClientError.server(message)
            }

            guard let result = object["result"] as? [String: Any],
                  let resultData = try? JSONSerialization.data(withJSONObject: result),
                  let usage = try? JSONDecoder().decode(CodexUsageData.self, from: resultData) else {
                throw CodexUsageClientError.unavailable
            }
            return usage
        }

        throw CodexUsageClientError.unavailable
    }
}

private final class CodexProcessController: @unchecked Sendable {
    private let process: Process
    private let input: FileHandle
    private let lock = NSLock()
    private var hasStopped = false

    init(process: Process, input: FileHandle) {
        self.process = process
        self.input = input
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        guard !hasStopped else { return }
        hasStopped = true

        try? input.close()
        if process.isRunning {
            process.terminate()
        }
    }
}
