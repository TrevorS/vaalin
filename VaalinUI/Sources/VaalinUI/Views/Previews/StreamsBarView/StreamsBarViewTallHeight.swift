// ABOUTME: Preview state for StreamsBarView with tall height (150pt) showing many streams

import SwiftUI
import VaalinCore

#Preview("Tall Height (150pt) - Many Streams") {
    let bufferManager = StreamBufferManager()
    let theme = Theme.catppuccinMocha()
    let viewModel = StreamsBarViewModel(
        streamBufferManager: bufferManager,
        theme: theme,
        initialActiveStreams: ["thoughts", "speech", "whispers", "logons"]
    )

    StreamsBarView(
        viewModel: viewModel,
        height: 150
    )
    .frame(width: 1000)
    .padding()
    .background(Color(hex: "#1e1e2e")!)
}
