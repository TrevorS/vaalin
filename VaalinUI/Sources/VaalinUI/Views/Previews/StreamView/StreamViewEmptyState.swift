// ABOUTME: Preview state for StreamView with no messages (empty buffer)

import SwiftUI
import VaalinCore

#Preview("Empty State") {
    let streamBufferManager = StreamBufferManager()
    let activeStreamIDs: Set<String> = ["thoughts"]

    let viewModel = StreamViewModel(
        streamBufferManager: streamBufferManager,
        activeStreamIDs: activeStreamIDs,
        theme: Theme.catppuccinMocha()
    )

    StreamView(
        viewModel: viewModel,
        activeStreamIDs: activeStreamIDs
    )
    .frame(width: 800, height: 600)
}
