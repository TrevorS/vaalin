// ABOUTME: Preview file for PanelContainer showing expanded and collapsed states

import SwiftUI

/// Preview provider for PanelContainer in both expanded and collapsed states.
///
/// Shows both states side-by-side to test collapsible panel functionality:
/// - **Expanded**: Panel content visible with "Hands" example
/// - **Collapsed**: Panel content hidden, showing header only with "Vitals" example
///
/// Uses `StatefulPreviewWrapper` to provide interactive toggle functionality.
struct PanelContainerStatesPreview: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview 1: Expanded state
            StatefulPreviewWrapper(isCollapsed: false) { isCollapsed in
                PanelContainer(
                    title: "Hands",
                    isCollapsed: isCollapsed,
                    height: 140
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Left: Empty")
                            .font(.system(size: 13, design: .monospaced))
                        Text("Right: Empty")
                            .font(.system(size: 13, design: .monospaced))
                        Text("Prepared: None")
                            .font(.system(size: 13, design: .monospaced))
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(width: 300, height: 200)
            .padding()
            .previewDisplayName("Expanded")
            .preferredColorScheme(.dark)

            // Preview 2: Collapsed state
            StatefulPreviewWrapper(isCollapsed: true) { isCollapsed in
                PanelContainer(
                    title: "Vitals",
                    isCollapsed: isCollapsed,
                    height: 160
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Health:")
                                .font(.system(size: 11, weight: .medium))
                            Text("100/100")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.green)
                        }
                        HStack {
                            Text("Mana:")
                                .font(.system(size: 11, weight: .medium))
                            Text("85/85")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(width: 300, height: 200)
            .padding()
            .previewDisplayName("Collapsed")
            .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Preview Helpers

/// Wrapper to provide stateful binding for previews.
///
/// SwiftUI previews are stateless by default, so @State doesn't work.
/// This wrapper provides a real @State binding for interactive previews.
private struct StatefulPreviewWrapper<Content: View>: View {
    @State private var isCollapsed: Bool
    private let content: (Binding<Bool>) -> Content

    init(isCollapsed: Bool, @ViewBuilder content: @escaping (Binding<Bool>) -> Content) {
        self._isCollapsed = State(initialValue: isCollapsed)
        self.content = content
    }

    var body: some View {
        content($isCollapsed)
    }
}
