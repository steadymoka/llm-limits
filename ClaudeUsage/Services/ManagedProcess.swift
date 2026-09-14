import Foundation

/// 자식 프로세스를 정확히 한 번만 정리한다. 타임아웃·취소·정상 종료 경로가
/// 동시에 stop()을 부를 수 있어 잠금이 필요하다.
final class ManagedProcess: @unchecked Sendable {
    private let process: Process
    private let input: FileHandle?
    private let lock = NSLock()
    private var hasStopped = false

    init(process: Process, input: FileHandle? = nil) {
        self.process = process
        self.input = input
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        guard !hasStopped else { return }
        hasStopped = true

        try? input?.close()
        if process.isRunning {
            process.terminate()
        }
    }
}

enum ExecutableLocator {
    /// GUI 앱으로 실행되면 PATH가 거의 비어 있으므로, PATH를 먼저 훑고
    /// 알려진 설치 위치를 이어서 확인한다.
    static func find(_ name: String, extraPaths: [String]) -> URL? {
        let fileManager = FileManager.default
        var candidates = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map { String($0) + "/" + name }
        candidates.append(contentsOf: extraPaths)

        for path in candidates where fileManager.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }
}
