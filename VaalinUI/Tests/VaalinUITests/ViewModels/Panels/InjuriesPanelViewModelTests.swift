// ABOUTME: Tests for InjuriesPanelViewModel EventBus subscription and injuries state updates

import Testing
import Foundation
@testable import VaalinUI
@testable import VaalinCore

/// Test suite for InjuriesPanelViewModel injuries panel state functionality
/// Validates EventBus subscription and injuries state updates per Issue #42 acceptance criteria
///
/// ## Protocol Validation
///
/// Tests validate the actual GemStone IV protocol based on expert analysis:
/// - **Only `<image>` tags** (not progressBar/radio/label)
/// - **Injury patterns**: `name="Injury1"`, `name="Injury2"`, `name="Injury3"`
/// - **Scar patterns**: `name="Scar1"`, `name="Scar2"`, `name="Scar3"`
/// - **Healthy state**: `name == id` (e.g., `<image id="head" name="head"/>`)
/// - **Filter healthSkin**: Ignore `<image id="healthSkin" .../>`
@MainActor
struct InjuriesPanelViewModelTests {

    // MARK: - Initialization Tests

    /// Test that InjuriesPanelViewModel initializes with default values
    ///
    /// Acceptance Criteria:
    /// - All body parts default to InjuryStatus(injuryType: .none, severity: 0)
    /// - All body parts are present in injuries dictionary
    @Test func test_defaults() async throws {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Verify all body parts are present
        #expect(viewModel.injuries.count == BodyPart.allCases.count)

        // Verify all parts default to .none severity
        for bodyPart in BodyPart.allCases {
            let status = viewModel.injuries[bodyPart]
            #expect(status != nil)
            #expect(status?.injuryType == InjuryType.none)
            #expect(status?.severity == 0)
        }
    }

    /// Test that InjuriesPanelViewModel initializes correctly
    ///
    /// Acceptance Criteria:
    /// - Initializes with EventBus reference
    @Test func test_initialization() async throws {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Verify defaults match acceptance criteria
        #expect(viewModel.injuries.count == BodyPart.allCases.count)
    }

    // MARK: - EventBus Subscription Tests

    /// Test that InjuriesPanelViewModel subscribes to injuries events
    ///
    /// Acceptance Criteria:
    /// - Subscribes to "metadata/dialogData" event on initialization
    @Test func test_subscribesToInjuriesEvents() async throws {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Verify subscription exists
        let handlerCount = await eventBus.handlerCount(for: "metadata/dialogData/injuries")
        #expect(handlerCount == 1)
    }

    // MARK: - Image Tag Parsing Tests

    /// Test that InjuriesPanelViewModel parses Injury1 pattern correctly
    ///
    /// Acceptance Criteria:
    /// - Parses <image id="head" name="Injury1"/> to extract injury type and severity 1
    @Test func test_parseInjury1Pattern() async throws {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Initially head has no injury
        #expect(viewModel.injuries[.head]?.injuryType == InjuryType.none)

        // Publish dialogData event with head injury rank 1
        let imageTag = GameTag(
            name: "image",
            text: nil,
            attrs: ["id": "head", "name": "Injury1"],
            children: [],
            state: .closed
        )
        let dialogTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "injuries"],
            children: [imageTag],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/injuries", data: dialogTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify head injury updated
        #expect(viewModel.injuries[.head]?.injuryType == .injury)
        #expect(viewModel.injuries[.head]?.severity == 1)
    }

    /// Test that InjuriesPanelViewModel parses Injury2 pattern correctly
    ///
    /// Acceptance Criteria:
    /// - Parses <image id="chest" name="Injury2"/> to extract injury severity 2
    @Test func test_parseInjury2Pattern() async throws {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let imageTag = GameTag(
            name: "image",
            text: nil,
            attrs: ["id": "chest", "name": "Injury2"],
            children: [],
            state: .closed
        )
        let dialogTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "injuries"],
            children: [imageTag],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/injuries", data: dialogTag)
        try? await Task.sleep(for: .milliseconds(10))

        #expect(viewModel.injuries[.chest]?.injuryType == .injury)
        #expect(viewModel.injuries[.chest]?.severity == 2)
    }

    /// Test that InjuriesPanelViewModel parses Injury3 pattern correctly
    ///
    /// Acceptance Criteria:
    /// - Parses <image id="abdomen" name="Injury3"/> to extract injury severity 3
    @Test func test_parseInjury3Pattern() async throws {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let imageTag = GameTag(
            name: "image",
            text: nil,
            attrs: ["id": "abdomen", "name": "Injury3"],
            children: [],
            state: .closed
        )
        let dialogTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "injuries"],
            children: [imageTag],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/injuries", data: dialogTag)
        try? await Task.sleep(for: .milliseconds(10))

        #expect(viewModel.injuries[.abdomen]?.injuryType == .injury)
        #expect(viewModel.injuries[.abdomen]?.severity == 3)
    }

    /// Test that InjuriesPanelViewModel parses Scar1 pattern correctly
    ///
    /// Acceptance Criteria:
    /// - Parses <image id="leftArm" name="Scar1"/> to extract scar severity 1
    @Test func test_parseScar1Pattern() async throws {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let imageTag = GameTag(
            name: "image",
            text: nil,
            attrs: ["id": "leftArm", "name": "Scar1"],
            children: [],
            state: .closed
        )
        let dialogTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "injuries"],
            children: [imageTag],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/injuries", data: dialogTag)
        try? await Task.sleep(for: .milliseconds(10))

        #expect(viewModel.injuries[.leftArm]?.injuryType == .scar)
        #expect(viewModel.injuries[.leftArm]?.severity == 1)
    }

    /// Test that InjuriesPanelViewModel parses Scar2 pattern correctly
    ///
    /// Acceptance Criteria:
    /// - Parses <image id="rightArm" name="Scar2"/> to extract scar severity 2
    @Test func test_parseScar2Pattern() async throws {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let imageTag = GameTag(
            name: "image",
            text: nil,
            attrs: ["id": "rightArm", "name": "Scar2"],
            children: [],
            state: .closed
        )
        let dialogTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "injuries"],
            children: [imageTag],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/injuries", data: dialogTag)
        try? await Task.sleep(for: .milliseconds(10))

        #expect(viewModel.injuries[.rightArm]?.injuryType == .scar)
        #expect(viewModel.injuries[.rightArm]?.severity == 2)
    }

    /// Test that InjuriesPanelViewModel parses Scar3 pattern correctly
    ///
    /// Acceptance Criteria:
    /// - Parses <image id="back" name="Scar3"/> to extract scar severity 3
    @Test func test_parseScar3Pattern() async throws {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let imageTag = GameTag(
            name: "image",
            text: nil,
            attrs: ["id": "back", "name": "Scar3"],
            children: [],
            state: .closed
        )
        let dialogTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "injuries"],
            children: [imageTag],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/injuries", data: dialogTag)
        try? await Task.sleep(for: .milliseconds(10))

        #expect(viewModel.injuries[.back]?.injuryType == .scar)
        #expect(viewModel.injuries[.back]?.severity == 3)
    }

    /// Test that InjuriesPanelViewModel parses healthy state correctly
    ///
    /// Acceptance Criteria:
    /// - When name == id, sets injury type to .none and severity to 0
    @Test func test_parseHealthyState() async throws {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // First set an injury
        let injuryTag = GameTag(
            name: "image",
            text: nil,
            attrs: ["id": "head", "name": "Injury2"],
            children: [],
            state: .closed
        )
        let dialogTag1 = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "injuries"],
            children: [injuryTag],
            state: .closed
        )
        await eventBus.publish("metadata/dialogData/injuries", data: dialogTag1)
        try? await Task.sleep(for: .milliseconds(10))
        #expect(viewModel.injuries[.head]?.injuryType == .injury)

        // Now heal it (name == id)
        let healthyTag = GameTag(
            name: "image",
            text: nil,
            attrs: ["id": "head", "name": "head"],
            children: [],
            state: .closed
        )
        let dialogTag2 = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "injuries"],
            children: [healthyTag],
            state: .closed
        )
        await eventBus.publish("metadata/dialogData/injuries", data: dialogTag2)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify healed
        #expect(viewModel.injuries[.head]?.injuryType == InjuryType.none)
        #expect(viewModel.injuries[.head]?.severity == 0)
    }

    /// Test that InjuriesPanelViewModel filters healthSkin sprite
    ///
    /// Acceptance Criteria:
    /// - <image id="healthSkin" ...> is ignored (mannequin sprite, not a body part)
    @Test func test_filterHealthSkinSprite() async throws {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let healthSkinTag = GameTag(
            name: "image",
            text: nil,
            attrs: ["id": "healthSkin", "name": "healthBar2"],
            children: [],
            state: .closed
        )
        let headTag = GameTag(
            name: "image",
            text: nil,
            attrs: ["id": "head", "name": "Injury1"],
            children: [],
            state: .closed
        )
        let dialogTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "injuries"],
            children: [healthSkinTag, headTag],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/injuries", data: dialogTag)
        try? await Task.sleep(for: .milliseconds(10))

        // healthSkin should be ignored, only head should update
        #expect(viewModel.injuries[.head]?.injuryType == .injury)
        #expect(viewModel.injuries[.head]?.severity == 1)
    }

    // MARK: - Mutually Exclusive Tests

    /// Test that injury and scar are mutually exclusive
    ///
    /// Acceptance Criteria:
    /// - A body part cannot have both injury and scar simultaneously
    /// - Latest update overwrites previous state
    @Test func test_injuryAndScarMutuallyExclusive() async throws {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // First set an injury
        let injuryTag = GameTag(
            name: "image",
            text: nil,
            attrs: ["id": "chest", "name": "Injury2"],
            children: [],
            state: .closed
        )
        let dialogTag1 = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "injuries"],
            children: [injuryTag],
            state: .closed
        )
        await eventBus.publish("metadata/dialogData/injuries", data: dialogTag1)
        try? await Task.sleep(for: .milliseconds(10))

        #expect(viewModel.injuries[.chest]?.injuryType == .injury)
        #expect(viewModel.injuries[.chest]?.severity == 2)

        // Now replace with scar
        let scarTag = GameTag(
            name: "image",
            text: nil,
            attrs: ["id": "chest", "name": "Scar1"],
            children: [],
            state: .closed
        )
        let dialogTag2 = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "injuries"],
            children: [scarTag],
            state: .closed
        )
        await eventBus.publish("metadata/dialogData/injuries", data: dialogTag2)
        try? await Task.sleep(for: .milliseconds(10))

        // Should be scar now, not injury
        #expect(viewModel.injuries[.chest]?.injuryType == .scar)
        #expect(viewModel.injuries[.chest]?.severity == 1)
    }

    // MARK: - State Management Tests

    /// Test that InjuriesPanelViewModel initializes all body parts
    ///
    /// Acceptance Criteria:
    /// - All BodyPart cases are present in injuries dictionary
    /// - All default to .none injury type
    @Test func test_allBodyPartsPresent() async throws {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let expectedParts = Set(BodyPart.allCases)
        let actualParts = Set(viewModel.injuries.keys)

        #expect(actualParts == expectedParts)

        // Verify each part is .none
        for bodyPart in BodyPart.allCases {
            #expect(viewModel.injuries[bodyPart]?.injuryType == InjuryType.none)
        }
    }

    /// Test that InjuriesPanelViewModel updates single location without affecting others
    ///
    /// Acceptance Criteria:
    /// - Updating one body part doesn't change other parts
    @Test func test_updateSingleLocation() async throws {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Initially all parts are .none
        #expect(viewModel.injuries[.head]?.injuryType == InjuryType.none)
        #expect(viewModel.injuries[.chest]?.injuryType == InjuryType.none)
        #expect(viewModel.injuries[.leftArm]?.injuryType == InjuryType.none)

        // Update only head
        let imageTag = GameTag(
            name: "image",
            text: nil,
            attrs: ["id": "head", "name": "Injury2"],
            children: [],
            state: .closed
        )
        let dialogTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "injuries"],
            children: [imageTag],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/injuries", data: dialogTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify only head changed
        #expect(viewModel.injuries[.head]?.injuryType == .injury)
        #expect(viewModel.injuries[.head]?.severity == 2)
        #expect(viewModel.injuries[.chest]?.injuryType == InjuryType.none)
        #expect(viewModel.injuries[.leftArm]?.injuryType == InjuryType.none)
    }

    /// Test that multiple injuries can be updated independently
    ///
    /// Acceptance Criteria:
    /// - Each body part updates independently in single dialogData event
    @Test func test_independentInjuryUpdates() async throws {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Update multiple body parts in one dialogData event
        let headImage = GameTag(
            name: "image",
            text: nil,
            attrs: ["id": "head", "name": "Injury1"],
            children: [],
            state: .closed
        )
        let chestImage = GameTag(
            name: "image",
            text: nil,
            attrs: ["id": "chest", "name": "Scar2"],
            children: [],
            state: .closed
        )
        let leftArmImage = GameTag(
            name: "image",
            text: nil,
            attrs: ["id": "leftArm", "name": "Injury3"],
            children: [],
            state: .closed
        )

        let dialogTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "injuries"],
            children: [headImage, chestImage, leftArmImage],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/injuries", data: dialogTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify all updated independently
        #expect(viewModel.injuries[.head]?.injuryType == .injury)
        #expect(viewModel.injuries[.head]?.severity == 1)
        #expect(viewModel.injuries[.chest]?.injuryType == .scar)
        #expect(viewModel.injuries[.chest]?.severity == 2)
        #expect(viewModel.injuries[.leftArm]?.injuryType == .injury)
        #expect(viewModel.injuries[.leftArm]?.severity == 3)
        // Other parts unchanged
        #expect(viewModel.injuries[.neck]?.injuryType == InjuryType.none)
    }

    // MARK: - Edge Cases

    /// Test that InjuriesPanelViewModel handles missing id attribute
    ///
    /// Acceptance Criteria:
    /// - Missing id attribute is ignored gracefully
    @Test func test_missingIdAttribute() async throws {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let imageTag = GameTag(
            name: "image",
            text: nil,
            attrs: ["name": "Injury1"],  // No id attribute
            children: [],
            state: .closed
        )
        let dialogTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "injuries"],
            children: [imageTag],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/injuries", data: dialogTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Should not crash, all parts still .none
        for bodyPart in BodyPart.allCases {
            #expect(viewModel.injuries[bodyPart]?.injuryType == InjuryType.none)
        }
    }

    /// Test that InjuriesPanelViewModel handles missing name attribute
    ///
    /// Acceptance Criteria:
    /// - Missing name attribute is ignored gracefully
    @Test func test_missingNameAttribute() async throws {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let imageTag = GameTag(
            name: "image",
            text: nil,
            attrs: ["id": "head"],  // No name attribute
            children: [],
            state: .closed
        )
        let dialogTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "injuries"],
            children: [imageTag],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/injuries", data: dialogTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Should not crash, head still .none
        #expect(viewModel.injuries[.head]?.injuryType == InjuryType.none)
    }

    /// Test that InjuriesPanelViewModel handles unknown body part IDs
    ///
    /// Acceptance Criteria:
    /// - Unknown body part IDs are ignored gracefully
    @Test func test_unknownBodyPartID() async throws {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let imageTag = GameTag(
            name: "image",
            text: nil,
            attrs: ["id": "unknownBodyPart", "name": "Injury3"],
            children: [],
            state: .closed
        )
        let dialogTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "injuries"],
            children: [imageTag],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/injuries", data: dialogTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Should not crash, all parts still .none
        for bodyPart in BodyPart.allCases {
            #expect(viewModel.injuries[bodyPart]?.injuryType == InjuryType.none)
        }
    }

    /// Test that InjuriesPanelViewModel handles unknown image name patterns
    ///
    /// Acceptance Criteria:
    /// - Unknown patterns are ignored gracefully
    @Test func test_unknownImagePattern() async throws {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let imageTag = GameTag(
            name: "image",
            text: nil,
            attrs: ["id": "head", "name": "UnknownPattern"],
            children: [],
            state: .closed
        )
        let dialogTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "injuries"],
            children: [imageTag],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/injuries", data: dialogTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Should not crash, head still at default
        // Note: resetInjuries() was called, so it's back to .none
        #expect(viewModel.injuries[.head]?.injuryType == InjuryType.none)
    }

    // MARK: - Multiple Updates Tests

    /// Test that InjuriesPanelViewModel handles multiple rapid updates
    ///
    /// Acceptance Criteria:
    /// - Handles rapid successive injury updates correctly
    @Test func test_multipleUpdates() async throws {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Publish multiple updates to same body part
        let patterns = ["Injury1", "Injury2", "Injury3", "Scar1"]

        for pattern in patterns {
            let imageTag = GameTag(
                name: "image",
                text: nil,
                attrs: ["id": "head", "name": pattern],
                children: [],
                state: .closed
            )
            let dialogTag = GameTag(
                name: "dialogData",
                text: nil,
                attrs: ["id": "injuries"],
                children: [imageTag],
                state: .closed
            )
            await eventBus.publish("metadata/dialogData/injuries", data: dialogTag)
            try? await Task.sleep(for: .milliseconds(5))
        }

        // Give final event time to process
        try? await Task.sleep(for: .milliseconds(10))

        // Verify final state is Scar1
        #expect(viewModel.injuries[.head]?.injuryType == .scar)
        #expect(viewModel.injuries[.head]?.severity == 1)
    }

    // MARK: - Empty/Reset Tests

    /// Test that InjuriesPanelViewModel can reset injuries to clean state
    ///
    /// Acceptance Criteria:
    /// - Publishing dialogData with no image tags clears all injuries
    @Test func test_resetToCleanState() async throws {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // First set some injuries
        let headImage = GameTag(
            name: "image",
            text: nil,
            attrs: ["id": "head", "name": "Injury3"],
            children: [],
            state: .closed
        )
        let chestImage = GameTag(
            name: "image",
            text: nil,
            attrs: ["id": "chest", "name": "Scar2"],
            children: [],
            state: .closed
        )
        let dialogTag1 = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "injuries"],
            children: [headImage, chestImage],
            state: .closed
        )
        await eventBus.publish("metadata/dialogData/injuries", data: dialogTag1)
        try? await Task.sleep(for: .milliseconds(10))

        #expect(viewModel.injuries[.head]?.injuryType == .injury)
        #expect(viewModel.injuries[.chest]?.injuryType == .scar)

        // Now reset with empty dialogData
        let emptyDialog = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "injuries"],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/dialogData/injuries", data: emptyDialog)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify reset to defaults
        #expect(viewModel.injuries[.head]?.injuryType == InjuryType.none)
        #expect(viewModel.injuries[.head]?.severity == 0)
        #expect(viewModel.injuries[.chest]?.injuryType == InjuryType.none)
        #expect(viewModel.injuries[.chest]?.severity == 0)
    }

    /// Test that InjuriesPanelViewModel handles dialogData with no children
    ///
    /// Acceptance Criteria:
    /// - Empty dialogData doesn't crash
    @Test func test_emptyDialogData() async throws {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        let emptyDialog = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "injuries"],
            children: [],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/injuries", data: emptyDialog)
        try? await Task.sleep(for: .milliseconds(10))

        // Should not crash, all still .none
        #expect(viewModel.injuries[.head]?.injuryType == InjuryType.none)
    }

    /// Test that InjuriesPanelViewModel filters non-injuries dialogs
    ///
    /// Acceptance Criteria:
    /// - Only processes dialogData with id="injuries"
    /// - Ignores other dialogs (spells, familiar, etc.)
    @Test func test_filterNonInjuriesDialogs() async throws {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Send dialogData for different window (e.g., spells)
        let imageTag = GameTag(
            name: "image",
            text: nil,
            attrs: ["id": "head", "name": "Injury3"],
            children: [],
            state: .closed
        )
        let spellsDialog = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "spells"],  // Not "injuries"
            children: [imageTag],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData", data: spellsDialog)
        try? await Task.sleep(for: .milliseconds(10))

        // Should be ignored, head still .none
        #expect(viewModel.injuries[.head]?.injuryType == InjuryType.none)
    }

    // MARK: - Lifecycle Tests

    /// Test that InjuriesPanelViewModel cleans up subscriptions on deinit
    ///
    /// Acceptance Criteria:
    /// - Unsubscribes from all events when deallocated
    @Test func test_unsubscribesOnDeinit() async throws {
        let eventBus = EventBus()

        do {
            let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
            await viewModel.setup()

            // Verify subscription exists
            let handlerCount = await eventBus.handlerCount(for: "metadata/dialogData/injuries")
            #expect(handlerCount == 1)
        }

        // InjuriesPanelViewModel should be deallocated here
        // Give deinit time to execute
        try? await Task.sleep(for: .milliseconds(50))

        // Verify subscription was removed
        let handlerCountAfter = await eventBus.handlerCount(for: "metadata/dialogData/injuries")
        #expect(handlerCountAfter == 0)
    }

    /// Test that multiple InjuriesPanelViewModels can subscribe to same EventBus
    ///
    /// Acceptance Criteria:
    /// - Multiple instances can coexist without conflict
    @Test func test_multipleViewModelsSubscribe() async throws {
        let eventBus = EventBus()
        let viewModel1 = InjuriesPanelViewModel(eventBus: eventBus)
        let viewModel2 = InjuriesPanelViewModel(eventBus: eventBus)
        await viewModel1.setup()
        await viewModel2.setup()

        // Verify both subscribed
        let handlerCount = await eventBus.handlerCount(for: "metadata/dialogData/injuries")
        #expect(handlerCount == 2)

        // Publish event
        let imageTag = GameTag(
            name: "image",
            text: nil,
            attrs: ["id": "head", "name": "Injury2"],
            children: [],
            state: .closed
        )
        let dialogTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "injuries"],
            children: [imageTag],
            state: .closed
        )
        await eventBus.publish("metadata/dialogData/injuries", data: dialogTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify both updated
        #expect(viewModel1.injuries[.head]?.injuryType == .injury)
        #expect(viewModel1.injuries[.head]?.severity == 2)
        #expect(viewModel2.injuries[.head]?.injuryType == .injury)
        #expect(viewModel2.injuries[.head]?.severity == 2)
    }

    // MARK: - BodyPart Mapping Tests

    /// Test that InjuriesPanelViewModel maps all BodyPart cases to image IDs
    ///
    /// Acceptance Criteria:
    /// - All BodyPart enum cases can be updated via image ID
    @Test func test_allBodyPartsMappable() async throws {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Test each body part can be updated
        for bodyPart in BodyPart.allCases {
            let imageTag = GameTag(
                name: "image",
                text: nil,
                attrs: ["id": bodyPart.rawValue, "name": "Injury1"],
                children: [],
                state: .closed
            )
            let dialogTag = GameTag(
                name: "dialogData",
                text: nil,
                attrs: ["id": "injuries"],
                children: [imageTag],
                state: .closed
            )

            await eventBus.publish("metadata/dialogData/injuries", data: dialogTag)
            try? await Task.sleep(for: .milliseconds(10))

            #expect(viewModel.injuries[bodyPart]?.injuryType == .injury)
            #expect(viewModel.injuries[bodyPart]?.severity == 1)

            // Reset for next test
            let resetImage = GameTag(
                name: "image",
                text: nil,
                attrs: ["id": bodyPart.rawValue, "name": bodyPart.rawValue],
                children: [],
                state: .closed
            )
            let resetDialog = GameTag(
                name: "dialogData",
                text: nil,
                attrs: ["id": "injuries"],
                children: [resetImage],
                state: .closed
            )
            await eventBus.publish("metadata/dialogData/injuries", data: resetDialog)
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    // MARK: - Status Computation Tests

    /// Test that injuryCount returns correct count of injured body parts
    ///
    /// Acceptance Criteria:
    /// - Returns 0 when all body parts are healthy
    /// - Returns correct count when body parts are injured
    /// - Excludes healthy body parts from count
    @Test func test_injuryCountComputation() async throws {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Initially all healthy, count should be 0
        #expect(viewModel.injuryCount == 0)

        // Add 3 injuries
        let headImage = GameTag(
            name: "image",
            text: nil,
            attrs: ["id": "head", "name": "Injury3"],
            children: [],
            state: .closed
        )
        let chestImage = GameTag(
            name: "image",
            text: nil,
            attrs: ["id": "chest", "name": "Scar1"],
            children: [],
            state: .closed
        )
        let leftArmImage = GameTag(
            name: "image",
            text: nil,
            attrs: ["id": "leftArm", "name": "Injury2"],
            children: [],
            state: .closed
        )

        let dialogTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "injuries"],
            children: [headImage, chestImage, leftArmImage],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/injuries", data: dialogTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify count is 3
        #expect(viewModel.injuryCount == 3)
    }

    /// Test that isHealthy returns true only when all body parts are healthy
    ///
    /// Acceptance Criteria:
    /// - Returns true when all body parts have severity 0 and type .none
    /// - Returns false when any body part has injury or scar
    @Test func test_isHealthyComputation() async throws {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Initially all healthy
        #expect(viewModel.isHealthy == true)

        // Add one injury
        let headImage = GameTag(
            name: "image",
            text: nil,
            attrs: ["id": "head", "name": "Injury1"],
            children: [],
            state: .closed
        )
        let dialogTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "injuries"],
            children: [headImage],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/injuries", data: dialogTag)
        try? await Task.sleep(for: .milliseconds(10))

        // No longer healthy
        #expect(viewModel.isHealthy == false)

        // Clear all injuries
        let emptyDialog = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "injuries"],
            children: [],
            state: .closed
        )
        await eventBus.publish("metadata/dialogData/injuries", data: emptyDialog)
        try? await Task.sleep(for: .milliseconds(10))

        // Healthy again
        #expect(viewModel.isHealthy == true)
    }

    /// Test that hasNervousDamage detects nervous system injuries
    ///
    /// Acceptance Criteria:
    /// - Returns false when nerves are healthy (severity 0, type .none)
    /// - Returns true when nerves have any injury (severity > 0)
    /// - Returns true when nerves have any scar (severity > 0)
    @Test func test_hasNervousDamageDetection() async throws {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Initially no nervous damage
        #expect(viewModel.hasNervousDamage == false)

        // Add nervous system injury
        let nervesImage = GameTag(
            name: "image",
            text: nil,
            attrs: ["id": "nerves", "name": "Injury2"],
            children: [],
            state: .closed
        )
        let dialogTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "injuries"],
            children: [nervesImage],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/injuries", data: dialogTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Should detect nervous damage
        #expect(viewModel.hasNervousDamage == true)
    }

    /// Test that hasNervousDamage detects nervous system scars
    ///
    /// Acceptance Criteria:
    /// - Returns true when nerves have scars (not just injuries)
    @Test func test_hasNervousDamageDetectsScar() async throws {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Add nervous system scar
        let nervesScarImage = GameTag(
            name: "image",
            text: nil,
            attrs: ["id": "nerves", "name": "Scar1"],
            children: [],
            state: .closed
        )
        let dialogTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "injuries"],
            children: [nervesScarImage],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/injuries", data: dialogTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Should detect nervous damage even from scar
        #expect(viewModel.hasNervousDamage == true)
    }

    /// Test that nervousSeverity returns correct severity level
    ///
    /// Acceptance Criteria:
    /// - Returns 0 when nerves are healthy
    /// - Returns 1-3 matching the severity of nervous system injury/scar
    @Test func test_nervousSeverityComputation() async throws {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Initially severity 0
        #expect(viewModel.nervousSeverity == 0)

        // Test each severity level
        for severity in 1...3 {
            let nervesImage = GameTag(
                name: "image",
                text: nil,
                attrs: ["id": "nerves", "name": "Injury\(severity)"],
                children: [],
                state: .closed
            )
            let dialogTag = GameTag(
                name: "dialogData",
                text: nil,
                attrs: ["id": "injuries"],
                children: [nervesImage],
                state: .closed
            )

            await eventBus.publish("metadata/dialogData/injuries", data: dialogTag)
            try? await Task.sleep(for: .milliseconds(10))

            #expect(viewModel.nervousSeverity == severity)
        }
    }

    /// Test that status computations update correctly when injuries change
    ///
    /// Acceptance Criteria:
    /// - All status properties update immediately when injuries dict changes
    /// - Status properties reflect current state accurately
    @Test func test_statusPropertiesUpdateWithInjuries() async throws {
        let eventBus = EventBus()
        let viewModel = InjuriesPanelViewModel(eventBus: eventBus)
        await viewModel.setup()

        // Initially healthy
        #expect(viewModel.isHealthy == true)
        #expect(viewModel.injuryCount == 0)
        #expect(viewModel.hasNervousDamage == false)
        #expect(viewModel.nervousSeverity == 0)

        // Add mixed injuries including nerves
        let headImage = GameTag(
            name: "image",
            text: nil,
            attrs: ["id": "head", "name": "Injury1"],
            children: [],
            state: .closed
        )
        let nervesImage = GameTag(
            name: "image",
            text: nil,
            attrs: ["id": "nerves", "name": "Injury3"],
            children: [],
            state: .closed
        )
        let dialogTag = GameTag(
            name: "dialogData",
            text: nil,
            attrs: ["id": "injuries"],
            children: [headImage, nervesImage],
            state: .closed
        )

        await eventBus.publish("metadata/dialogData/injuries", data: dialogTag)
        try? await Task.sleep(for: .milliseconds(10))

        // Verify all status properties updated
        #expect(viewModel.isHealthy == false)
        #expect(viewModel.injuryCount == 2)
        #expect(viewModel.hasNervousDamage == true)
        #expect(viewModel.nervousSeverity == 3)
    }
}
