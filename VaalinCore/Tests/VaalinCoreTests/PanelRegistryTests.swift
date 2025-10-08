// ABOUTME: Tests for PanelRegistry actor - panel registration, lookup, and thread-safety

import Testing
import Foundation
import VaalinCore

#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Test suite for PanelRegistry actor
///
/// Tests panel registration, lookup by ID, filtering by column,
/// duplicate ID handling, and concurrent access for thread safety.
///
/// **Coverage Target**: >80% (business logic)
struct PanelRegistryTests {
    // MARK: - Registration Tests

    /// Test registering a panel and retrieving it by ID
    @Test func registerPanel() async throws {
        let registry = PanelRegistry()

        let panel = PanelInfo(
            id: "hands",
            title: "Hands",
            defaultVisible: true,
            defaultColumn: .left,
            defaultHeight: 140
        )

        await registry.register(panel)

        let retrieved = await registry.panel(withID: "hands")
        #expect(retrieved != nil)
        #expect(retrieved?.id == "hands")
        #expect(retrieved?.title == "Hands")
        #expect(retrieved?.defaultVisible == true)
        #expect(retrieved?.defaultColumn == .left)
        #expect(retrieved?.defaultHeight == 140)
    }

    /// Test default visibility settings for panels
    @Test func panelVisibility() async throws {
        let registry = PanelRegistry()

        let visiblePanel = PanelInfo(
            id: "vitals",
            title: "Vitals",
            defaultVisible: true,
            defaultColumn: .left,
            defaultHeight: 160
        )

        let hiddenPanel = PanelInfo(
            id: "debug",
            title: "Debug",
            defaultVisible: false,
            defaultColumn: .right,
            defaultHeight: 200
        )

        await registry.register(visiblePanel)
        await registry.register(hiddenPanel)

        let vitals = await registry.panel(withID: "vitals")
        #expect(vitals?.defaultVisible == true)

        let debug = await registry.panel(withID: "debug")
        #expect(debug?.defaultVisible == false)
    }

    /// Test retrieving all registered panels
    @Test func allPanels() async throws {
        let registry = PanelRegistry()

        let hands = PanelInfo(
            id: "hands",
            title: "Hands",
            defaultVisible: true,
            defaultColumn: .left,
            defaultHeight: 140
        )

        let vitals = PanelInfo(
            id: "vitals",
            title: "Vitals",
            defaultVisible: true,
            defaultColumn: .left,
            defaultHeight: 160
        )

        let compass = PanelInfo(
            id: "compass",
            title: "Compass",
            defaultVisible: true,
            defaultColumn: .right,
            defaultHeight: 120
        )

        await registry.register(hands)
        await registry.register(vitals)
        await registry.register(compass)

        let all = await registry.allPanels()
        #expect(all.count == 3)

        let ids = all.map { $0.id }.sorted()
        #expect(ids == ["compass", "hands", "vitals"])
    }

    /// Test filtering panels by column
    @Test func panelsForColumn() async throws {
        let registry = PanelRegistry()

        let hands = PanelInfo(
            id: "hands",
            title: "Hands",
            defaultVisible: true,
            defaultColumn: .left,
            defaultHeight: 140
        )

        let vitals = PanelInfo(
            id: "vitals",
            title: "Vitals",
            defaultVisible: true,
            defaultColumn: .left,
            defaultHeight: 160
        )

        let compass = PanelInfo(
            id: "compass",
            title: "Compass",
            defaultVisible: true,
            defaultColumn: .right,
            defaultHeight: 120
        )

        let spells = PanelInfo(
            id: "spells",
            title: "Spells",
            defaultVisible: true,
            defaultColumn: .right,
            defaultHeight: 180
        )

        await registry.register(hands)
        await registry.register(vitals)
        await registry.register(compass)
        await registry.register(spells)

        let leftPanels = await registry.panels(forColumn: .left)
        #expect(leftPanels.count == 2)
        #expect(leftPanels.contains { $0.id == "hands" })
        #expect(leftPanels.contains { $0.id == "vitals" })

        let rightPanels = await registry.panels(forColumn: .right)
        #expect(rightPanels.count == 2)
        #expect(rightPanels.contains { $0.id == "compass" })
        #expect(rightPanels.contains { $0.id == "spells" })
    }

    /// Test that registering a duplicate ID overwrites the previous panel
    @Test func duplicateID() async throws {
        let registry = PanelRegistry()

        let original = PanelInfo(
            id: "test",
            title: "Original",
            defaultVisible: true,
            defaultColumn: .left,
            defaultHeight: 100
        )

        let updated = PanelInfo(
            id: "test",
            title: "Updated",
            defaultVisible: false,
            defaultColumn: .right,
            defaultHeight: 200
        )

        await registry.register(original)
        await registry.register(updated)

        let retrieved = await registry.panel(withID: "test")
        #expect(retrieved?.title == "Updated")
        #expect(retrieved?.defaultVisible == false)
        #expect(retrieved?.defaultColumn == .right)
        #expect(retrieved?.defaultHeight == 200)

        // Should only have one panel, not two
        let all = await registry.allPanels()
        #expect(all.count == 1)
    }

    /// Test concurrent access to registry (thread safety)
    @Test func concurrentAccess() async throws {
        let registry = PanelRegistry()

        // Register multiple panels concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let panel = PanelInfo(
                        id: "panel\(i)",
                        title: "Panel \(i)",
                        defaultVisible: true,
                        defaultColumn: i % 2 == 0 ? .left : .right,
                        defaultHeight: CGFloat(100 + i * 10)
                    )
                    await registry.register(panel)
                }
            }
        }

        // Verify all panels were registered
        let all = await registry.allPanels()
        #expect(all.count == 10)

        // Read concurrently
        await withTaskGroup(of: PanelInfo?.self) { group in
            for i in 0..<10 {
                group.addTask {
                    await registry.panel(withID: "panel\(i)")
                }
            }

            var results: [PanelInfo?] = []
            for await result in group {
                results.append(result)
            }

            #expect(results.count == 10)
            #expect(results.compactMap { $0 }.count == 10)
        }
    }

    /// Test looking up non-existent panel returns nil
    @Test func nonExistentPanel() async throws {
        let registry = PanelRegistry()

        let result = await registry.panel(withID: "nonexistent")
        #expect(result == nil)
    }

    /// Test empty registry returns empty arrays
    @Test func emptyRegistry() async throws {
        let registry = PanelRegistry()

        let all = await registry.allPanels()
        #expect(all.isEmpty)

        let leftPanels = await registry.panels(forColumn: .left)
        #expect(leftPanels.isEmpty)

        let rightPanels = await registry.panels(forColumn: .right)
        #expect(rightPanels.isEmpty)
    }
}

// MARK: - PanelInfo Tests

/// Test suite for PanelInfo model
struct PanelInfoTests {
    /// Test PanelInfo Codable encoding/decoding
    @Test func codableRoundTrip() throws {
        let original = PanelInfo(
            id: "hands",
            title: "Hands",
            defaultVisible: true,
            defaultColumn: .left,
            defaultHeight: 140
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PanelInfo.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.title == original.title)
        #expect(decoded.defaultVisible == original.defaultVisible)
        #expect(decoded.defaultColumn == original.defaultColumn)
        #expect(decoded.defaultHeight == original.defaultHeight)
    }

    /// Test PanelInfo Equatable conformance
    @Test func equality() throws {
        let panel1 = PanelInfo(
            id: "hands",
            title: "Hands",
            defaultVisible: true,
            defaultColumn: .left,
            defaultHeight: 140
        )

        let panel2 = PanelInfo(
            id: "hands",
            title: "Hands",
            defaultVisible: true,
            defaultColumn: .left,
            defaultHeight: 140
        )

        let panel3 = PanelInfo(
            id: "vitals",
            title: "Vitals",
            defaultVisible: true,
            defaultColumn: .left,
            defaultHeight: 160
        )

        #expect(panel1 == panel2)
        #expect(panel1 != panel3)
    }
}

// MARK: - PanelColumn Tests

/// Test suite for PanelColumn enum
struct PanelColumnTests {
    /// Test PanelColumn Codable encoding/decoding
    @Test func codableRoundTrip() throws {
        let left = PanelColumn.left
        let right = PanelColumn.right

        let encoder = JSONEncoder()
        let leftData = try encoder.encode(left)
        let rightData = try encoder.encode(right)

        let decoder = JSONDecoder()
        let decodedLeft = try decoder.decode(PanelColumn.self, from: leftData)
        let decodedRight = try decoder.decode(PanelColumn.self, from: rightData)

        #expect(decodedLeft == .left)
        #expect(decodedRight == .right)
    }
}
