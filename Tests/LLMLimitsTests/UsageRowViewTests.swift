import SwiftUI
import XCTest
@testable import LLMLimits

final class UsageRowViewTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func view(windowMinutes: Int?, resetsIn minutes: Double?) -> UsageRowView {
        UsageRowView(
            row: UsageRow(
                id: "row",
                title: "5시간 세션",
                metric: UsageMetric(
                    utilization: 30,
                    resetsAt: minutes.map { now.addingTimeInterval($0 * 60) }
                ),
                windowMinutes: windowMinutes
            ),
            showsAbsoluteReset: true,
            now: now
        )
    }

    @MainActor
    func testWindowProgressIsHowMuchOfTheWindowHasPassed() throws {
        // 5시간 창에 1시간 남았으면 4시간이 지났다.
        XCTAssertEqual(try XCTUnwrap(view(windowMinutes: 300, resetsIn: 60).windowProgress), 0.8, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(view(windowMinutes: 300, resetsIn: 300).windowProgress), 0, accuracy: 0.001)
        XCTAssertEqual(
            try XCTUnwrap(view(windowMinutes: 10_080, resetsIn: 1_440).windowProgress),
            6.0 / 7.0,
            accuracy: 0.001
        )
    }

    /// 리셋 시각이 지났는데 스냅샷이 아직 안 갱신된 계정도 있다.
    /// 그럴 때 막대가 트랙을 넘거나 음수로 접히면 안 된다.
    @MainActor
    func testWindowProgressIsClampedToTheWindow() throws {
        XCTAssertEqual(try XCTUnwrap(view(windowMinutes: 300, resetsIn: -120).windowProgress), 1)
        XCTAssertEqual(try XCTUnwrap(view(windowMinutes: 300, resetsIn: 900).windowProgress), 0)
    }

    /// 근거가 없으면 그리지 않는다. 창 길이나 리셋 시각 없이 그린 막대는
    /// 아무 뜻도 없으면서 다 읽은 것처럼 보인다.
    @MainActor
    func testWindowProgressNeedsBothWindowLengthAndReset() {
        XCTAssertNil(view(windowMinutes: nil, resetsIn: 60).windowProgress)
        XCTAssertNil(view(windowMinutes: 300, resetsIn: nil).windowProgress)
        XCTAssertNil(view(windowMinutes: 0, resetsIn: 60).windowProgress)
    }

    /// 기간 막대가 행 안에 깔리므로 행 높이는 그대로여야 한다.
    @MainActor
    func testWindowBarDoesNotChangeRowHeight() throws {
        let withBar = try XCTUnwrap(ImageRenderer(content: view(windowMinutes: 300, resetsIn: 60)).nsImage)
        let withoutBar = try XCTUnwrap(ImageRenderer(content: view(windowMinutes: nil, resetsIn: nil)).nsImage)

        XCTAssertEqual(withBar.size.height, 20)
        XCTAssertEqual(withBar.size.height, withoutBar.size.height)
    }
}
