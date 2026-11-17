import XCTest

@testable import OrcaGatewayCore

/// A8.4 (Swift core): the app's one queue of showSnackbar and showToast, as
/// Flutter's root ScaffoldMessenger runs it (sdk/lib/src/state/
/// action_executor.dart:393-423; material scaffold.dart:371-392, :438-449,
/// :661-674; snack_bar.dart:30, :323): first in, first shown; each bar
/// enters in 250 ms, shows its duration counted from when it is fully in,
/// leaves in 250 ms, and only then does the next enter. Time is passed in.
/// The same cases as Kotlin's SnackbarQueueTest.
final class SnackbarQueueTests: XCTestCase {
    /// Runs the queue 1 ms at a time until it is idle; for each item, the
    /// ms it spent showing, in the order the items came to the head.
    private func run(_ queue: inout SnackbarQueue) -> [(message: String, shownMs: Int)] {
        var out: [(id: Int, message: String, shownMs: Int)] = []
        var guardMs = 0
        while let item = queue.current, guardMs < 100_000 {
            if out.last?.id != item.id { out.append((item.id, item.message, 0)) }
            if queue.phase == .showing { out[out.count - 1].shownMs += 1 }
            queue.advance(by: 1)
            guardMs += 1
        }
        return out.map { ($0.message, $0.shownMs) }
    }

    /// A8.4: whatever comes in, snackbar or toast, comes to the head in the
    /// order it came.
    func testA8_4_ItemsShowInArrivalOrder() {
        var queue = SnackbarQueue()
        queue.show(.snackbar, message: "one")
        queue.show(.toast, message: "two")
        queue.show(.snackbar, message: "three")
        XCTAssertEqual(queue.items.map(\.message), ["one", "two", "three"])
        XCTAssertEqual(queue.current?.message, "one")
        XCTAssertEqual(run(&queue).map(\.message), ["one", "two", "three"])
        XCTAssertNil(queue.current)
        XCTAssertNil(queue.phase)
    }

    /// A8.4: a snackbar with no duration shows 4000 ms, a toast 2000 ms
    /// (action_executor.dart:395, :410); a duration given is kept.
    func testA8_4_DurationsDefaultTo4000ForASnackbarAnd2000ForAToast() {
        XCTAssertEqual(SnackbarQueue.snackbarDurationMs, 4000)
        XCTAssertEqual(SnackbarQueue.toastDurationMs, 2000)
        var queue = SnackbarQueue()
        XCTAssertEqual(queue.show(.snackbar, message: "a").durationMs, 4000)
        XCTAssertEqual(queue.show(.toast, message: "b").durationMs, 2000)
        XCTAssertEqual(queue.show(.snackbar, message: "c", durationMs: 1500).durationMs, 1500)
        XCTAssertEqual(queue.show(.toast, message: "d", durationMs: 3000).durationMs, 3000)
        XCTAssertEqual(queue.items.map(\.kind), [.snackbar, .toast, .snackbar, .toast])
        let shown = run(&queue)
        XCTAssertEqual(shown.map(\.message), ["a", "b", "c", "d"])
        XCTAssertEqual(shown.map(\.shownMs), [4000, 2000, 1500, 3000])
    }

    /// A8.4: a bar is half in after 125 ms and fully in at 250 (snack_bar
    /// .dart:30), then shows its duration, then is half out 125 ms later and
    /// gone at 250; the queue is idle after.
    func testA8_4_ABarEnters250ThenShowsItsDurationThenLeaves250() {
        var queue = SnackbarQueue()
        queue.show(.snackbar, message: "hi", durationMs: 1000)
        XCTAssertEqual(queue.phase, .entering)
        XCTAssertEqual(queue.reveal, 0)
        XCTAssertEqual(queue.untilNextChangeMs, 250)

        queue.advance(by: 125)
        XCTAssertEqual(queue.phase, .entering)
        XCTAssertEqual(queue.reveal, 0.5)
        XCTAssertEqual(queue.untilNextChangeMs, 125)

        queue.advance(by: 125)
        XCTAssertEqual(queue.phase, .showing)
        XCTAssertEqual(queue.reveal, 1)
        XCTAssertEqual(queue.untilNextChangeMs, 1000)

        queue.advance(by: 999)
        XCTAssertEqual(queue.phase, .showing)
        XCTAssertEqual(queue.untilNextChangeMs, 1)

        queue.advance(by: 1)
        XCTAssertEqual(queue.phase, .leaving)
        XCTAssertEqual(queue.reveal, 1)
        XCTAssertEqual(queue.untilNextChangeMs, 250)

        queue.advance(by: 125)
        XCTAssertEqual(queue.phase, .leaving)
        XCTAssertEqual(queue.reveal, 0.5)
        XCTAssertEqual(queue.current?.message, "hi")

        queue.advance(by: 125)
        XCTAssertNil(queue.phase)
        XCTAssertNil(queue.current)
        XCTAssertEqual(queue.items, [])
        XCTAssertEqual(queue.reveal, 0)
        XCTAssertNil(queue.untilNextChangeMs)
    }

    /// A8.4: the duration's count starts when the bar is fully in, not when
    /// it was shown (scaffold.dart:661-674): 4000 ms after showSnackbar the
    /// bar still has 250 ms to show; one long step carries over every phase
    /// it crosses.
    func testA8_4_TheDurationCountsOnlyOnceTheBarIsFullyIn() {
        var queue = SnackbarQueue()
        queue.show(.snackbar, message: "hi")
        queue.advance(by: 4000)
        XCTAssertEqual(queue.phase, .showing)
        XCTAssertEqual(queue.untilNextChangeMs, 250)
        queue.advance(by: 249)
        XCTAssertEqual(queue.phase, .showing)
        queue.advance(by: 1)
        XCTAssertEqual(queue.phase, .leaving)

        var once = SnackbarQueue()
        once.show(.toast, message: "t")
        once.advance(by: 250 + 2000 + 100)
        XCTAssertEqual(once.phase, .leaving)
        XCTAssertEqual(once.reveal, 0.6, accuracy: 1e-9)
        XCTAssertEqual(once.untilNextChangeMs, 150)
    }

    /// A8.4: a swipe takes the bar away at once, whatever its phase, with no
    /// leave animation (the UI has slid it off with the drag: Flutter's
    /// Dismissible, then removeCurrentSnackBar, snack_bar.dart:859-871,
    /// :865), and the next starts entering at once. A swipe on an idle queue
    /// changes nothing.
    func testA8_4_ASwipeRemovesTheBarAtOnce() {
        var queue = SnackbarQueue()
        queue.swipe()
        XCTAssertNil(queue.phase)
        XCTAssertNil(queue.current)

        queue.show(.snackbar, message: "a")
        queue.show(.snackbar, message: "b")
        queue.show(.snackbar, message: "c", durationMs: 1000)
        queue.advance(by: 250 + 100)
        XCTAssertEqual(queue.phase, .showing)
        queue.swipe()
        XCTAssertEqual(queue.current?.message, "b")
        XCTAssertEqual(queue.phase, .entering)
        XCTAssertEqual(queue.reveal, 0)
        XCTAssertEqual(queue.untilNextChangeMs, 250)
        XCTAssertEqual(queue.items.map(\.message), ["b", "c"])

        queue.advance(by: 100)
        XCTAssertEqual(queue.phase, .entering)
        queue.swipe()
        XCTAssertEqual(queue.current?.message, "c")
        XCTAssertEqual(queue.phase, .entering)
        XCTAssertEqual(queue.reveal, 0)

        queue.advance(by: 250 + 1000 + 100)
        XCTAssertEqual(queue.phase, .leaving)
        queue.swipe()
        XCTAssertNil(queue.phase)
        XCTAssertNil(queue.current)
        XCTAssertEqual(queue.items, [])
        XCTAssertEqual(queue.reveal, 0)
        XCTAssertNil(queue.untilNextChangeMs)
    }

    /// A8.4: a bar shown while another shows waits its turn: the one showing
    /// keeps its time, and every bar shows its whole duration.
    func testA8_4_NothingIsDroppedOrReplaced() {
        var queue = SnackbarQueue()
        queue.show(.snackbar, message: "A")
        queue.advance(by: 1000)
        let b = queue.show(.snackbar, message: "B")
        let c = queue.show(.toast, message: "C")
        XCTAssertNotEqual(b.id, c.id)
        XCTAssertEqual(queue.current?.message, "A")
        XCTAssertEqual(queue.phase, .showing)
        XCTAssertEqual(queue.untilNextChangeMs, 3250)
        XCTAssertEqual(queue.items.map(\.message), ["A", "B", "C"])

        let shown = run(&queue)
        XCTAssertEqual(shown.map(\.message), ["A", "B", "C"])
        XCTAssertEqual(shown.map(\.shownMs), [3250, 4000, 2000])
    }

    /// A8.4: the next bar starts in only when the one before has fully left
    /// (scaffold.dart:438-449), and at that very moment.
    func testA8_4_TheNextEntersOnlyAfterThePreviousHasLeft() {
        var queue = SnackbarQueue()
        queue.show(.snackbar, message: "A", durationMs: 1000)
        queue.show(.snackbar, message: "B", durationMs: 1000)
        queue.advance(by: 250 + 1000 + 249)
        XCTAssertEqual(queue.current?.message, "A")
        XCTAssertEqual(queue.phase, .leaving)
        XCTAssertEqual(queue.reveal, 1.0 / 250, accuracy: 1e-9)

        queue.advance(by: 1)
        XCTAssertEqual(queue.current?.message, "B")
        XCTAssertEqual(queue.phase, .entering)
        XCTAssertEqual(queue.reveal, 0)
        XCTAssertEqual(queue.untilNextChangeMs, 250)
        XCTAssertEqual(queue.items.map(\.message), ["B"])

        var long = SnackbarQueue()
        long.show(.snackbar, message: "A", durationMs: 1000)
        long.show(.toast, message: "B")
        long.advance(by: 250 + 1000 + 250 + 100)
        XCTAssertEqual(long.current?.message, "B")
        XCTAssertEqual(long.phase, .entering)
        XCTAssertEqual(long.reveal, 0.4, accuracy: 1e-9)
    }
}
