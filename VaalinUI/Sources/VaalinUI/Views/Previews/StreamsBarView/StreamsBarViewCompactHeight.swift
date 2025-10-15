// ABOUTME: Preview state for StreamsBarView with compact height (80pt)

import SwiftUI
import VaalinCore

#Preview("Compact Height (80pt)") {
    let bufferManager = StreamBufferManager()
    let theme = Theme.catppuccinMocha()
    let viewModel = StreamsBarViewModel(
        streamBufferManager: bufferManager,
        theme: theme,
        initialActiveStreams: ["thoughts", "speech"]
    )

    StreamsBarView(
        viewModel: viewModel,
        height: 80
    )
    .frame(width: 600)
    .padding()
    .background(Color(hex: "#1e1e2e")!)
}
