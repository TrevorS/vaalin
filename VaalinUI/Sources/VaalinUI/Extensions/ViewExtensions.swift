// ABOUTME: Shared SwiftUI View extension utilities for conditional modifiers and common patterns

import SwiftUI

public extension View {
    /// Applies a transformation if condition is true.
    ///
    /// Enables conditional application of view modifiers without breaking the view builder chain.
    ///
    /// ## Example Usage
    /// ```swift
    /// Text("Hello")
    ///     .if(isActive) { view in
    ///         view.foregroundColor(.green)
    ///     }
    /// ```
    ///
    /// ## Use Cases
    /// - Apply modifiers based on boolean conditions
    /// - Add accessibility traits conditionally
    /// - Apply styling based on state
    /// - Chain multiple conditional modifiers
    ///
    /// ## Performance
    /// - View builder optimization means no performance penalty
    /// - Both branches evaluated at compile time
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
