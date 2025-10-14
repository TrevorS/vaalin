// ABOUTME: Preview state for StreamsBarView with standard height (112pt)

import SwiftUI
import VaalinCore

#Preview("Standard Height (112pt)") {
    let bufferManager = StreamBufferManager()
    let theme = Theme.catppuccinMocha()
    let viewModel = StreamsBarViewModel(
        streamBufferManager: bufferManager,
        theme: theme,
        initialActiveStreams: ["thoughts", "speech", "whispers", "logons"]
    )

    StreamsBarView(
        viewModel: viewModel,
        height: 112
    )
    .frame(width: 800)
    .padding()
    .background(Color(hex: "#1e1e2e")!)
}
