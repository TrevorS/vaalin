// ABOUTME: Auto-scroll behavior tests for GameLogView - validates smart scroll management

import AppKit
import Foundation
import os
import SwiftUI
import Testing
@testable import VaalinCore
@testable import VaalinUI

/// Tests for GameLogView auto-scroll behavior.
///
/// Validates smart auto-scroll management:
/// - Auto-scroll enabled on initialization
/// - Auto-scroll disables when user scrolls up
/// - Auto-scroll re-enables after 3 seconds idle
/// - Auto-scroll re-enables immediately when user returns to bottom
/// - Task cancellation on deinit prevents crashes
@Suite("GameLogView Auto-Scroll Tests")
@MainActor
struct GameLogViewAutoScrollTests {
    // MARK: - Test Helpers

    /// Create a GameTag for testing
    private func makeTag(text: String) -> GameTag {
        GameTag(
            name: "output",
            text: text,
            attrs: [:],
            children: [],
            state: .closed
        )
    }

    // MARK: - Coordinator Tests

    /// Test auto-scroll is enabled on initialization
    @Test("Auto-scroll enabled by default")
    func test_autoScrollEnabledByDefault() async {
        let coordinator = GameLogView.Coordinator(
            logger: Logger(subsystem: "test", category: "test")
        )

        #expect(coordinator.autoScrollEnabled == true, "Auto-scroll should be enabled by default")
    }

    /// Test auto-scroll disabled when scrolled away from bottom
    @Test("Auto-scroll disables when scrolled away from bottom")
    func test_autoScrollDisablesWhenScrolledUp() async {
        let coordinator = GameLogView.Coordinator(
            logger: Logger(subsystem: "test", category: "test")
        )

        // Create mock scroll view and text view
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 1000))
        textView.textStorage?.append(NSAttributedString(string: String(repeating: "Line\n", count: 100)))

        scrollView.documentView = textView
        coordinator.scrollView = scrollView
        coordinator.textView = textView

        // Scroll to top (away from bottom)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))

        // Simulate scroll notification
        let notification = Notification(
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        coordinator.scrollViewDidScroll(notification)

        // Auto-scroll should be disabled
        #expect(coordinator.autoScrollEnabled == false, "Auto-scroll should disable when scrolled up")
    }

    /// Test auto-scroll re-enables after 3 seconds idle
    @Test("Auto-scroll re-enables after 3 seconds idle")
    func test_autoScrollReenablesAfter3Seconds() async {
        let coordinator = GameLogView.Coordinator(
            logger: Logger(subsystem: "test", category: "test")
        )

        // Create mock scroll view and text view
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 1000))
        textView.textStorage?.append(NSAttributedString(string: String(repeating: "Line\n", count: 100)))

        scrollView.documentView = textView
        coordinator.scrollView = scrollView
        coordinator.textView = textView

        // Scroll to top (away from bottom)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))

        // Simulate scroll notification (disables auto-scroll)
        let notification = Notification(
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        coordinator.scrollViewDidScroll(notification)

        #expect(coordinator.autoScrollEnabled == false, "Auto-scroll should be disabled initially")

        // Wait 3.5 seconds for task to complete
        try? await Task.sleep(for: .seconds(3.5))

        // Auto-scroll should be re-enabled
        #expect(coordinator.autoScrollEnabled == true, "Auto-scroll should re-enable after 3 seconds")
    }

    /// Test auto-scroll re-enables immediately when returning to bottom
    @Test("Auto-scroll re-enables immediately when scrolling to bottom")
    func test_autoScrollReenablesImmediatelyAtBottom() async {
        let coordinator = GameLogView.Coordinator(
            logger: Logger(subsystem: "test", category: "test")
        )

        // Create mock scroll view and text view
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 1000))
        textView.textStorage?.append(NSAttributedString(string: String(repeating: "Line\n", count: 100)))

        scrollView.documentView = textView
        coordinator.scrollView = scrollView
        coordinator.textView = textView

        // Scroll to top (away from bottom)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))

        // Simulate scroll notification (disables auto-scroll)
        let notificationUp = Notification(
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        coordinator.scrollViewDidScroll(notificationUp)

        #expect(coordinator.autoScrollEnabled == false, "Auto-scroll should be disabled after scrolling up")

        // Scroll to bottom (within 50pt threshold)
        let maxY = textView.bounds.height - scrollView.contentSize.height
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: maxY))

        // Simulate scroll notification (should re-enable immediately)
        let notificationDown = Notification(
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        coordinator.scrollViewDidScroll(notificationDown)

        // Auto-scroll should be re-enabled immediately (no 3s wait)
        #expect(coordinator.autoScrollEnabled == true, "Auto-scroll should re-enable immediately at bottom")
    }

    /// Test task cancellation prevents crashes on deinit
    @Test("Task cancellation prevents crashes on deinit")
    func test_taskCancellationOnDeinit() async {
        var coordinator: GameLogView.Coordinator? = GameLogView.Coordinator(
            logger: Logger(subsystem: "test", category: "test")
        )

        // Create mock scroll view and text view
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 1000))
        textView.textStorage?.append(NSAttributedString(string: String(repeating: "Line\n", count: 100)))

        scrollView.documentView = textView
        coordinator?.scrollView = scrollView
        coordinator?.textView = textView

        // Scroll to top (away from bottom)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))

        // Simulate scroll notification (starts 3s timer)
        let notification = Notification(
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        coordinator?.scrollViewDidScroll(notification)

        #expect(coordinator?.autoScrollEnabled == false, "Auto-scroll should be disabled")

        // Deallocate coordinator (triggers deinit, should cancel task)
        coordinator = nil

        // Wait 3.5 seconds (task should have been cancelled, so no crash)
        try? await Task.sleep(for: .seconds(3.5))

        // If we got here without crashing, task cancellation worked
        // Test passes by not crashing (no explicit assertion needed)
    }

    /// Test multiple rapid scrolls cancel previous tasks
    @Test("Multiple rapid scrolls cancel previous re-enable tasks")
    func test_rapidScrollsCancelPreviousTasks() async {
        let coordinator = GameLogView.Coordinator(
            logger: Logger(subsystem: "test", category: "test")
        )

        // Create mock scroll view and text view
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 1000))
        textView.textStorage?.append(NSAttributedString(string: String(repeating: "Line\n", count: 100)))

        scrollView.documentView = textView
        coordinator.scrollView = scrollView
        coordinator.textView = textView

        // Scroll to top (away from bottom)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))

        // Simulate 5 rapid scroll notifications (each should cancel previous task)
        for _ in 0..<5 {
            let notification = Notification(
                name: NSView.boundsDidChangeNotification,
                object: scrollView.contentView
            )
            coordinator.scrollViewDidScroll(notification)
            try? await Task.sleep(for: .milliseconds(100))  // Small delay between scrolls
        }

        #expect(coordinator.autoScrollEnabled == false, "Auto-scroll should still be disabled")

        // Wait 3.5 seconds for the LAST task to complete (previous 4 should have been cancelled)
        try? await Task.sleep(for: .seconds(3.5))

        // Only the last task should have completed, re-enabling auto-scroll
        #expect(coordinator.autoScrollEnabled == true, "Auto-scroll should re-enable after final task")
    }
}
