// ABOUTME: BodyPart enum defines all body locations that can sustain injuries

import Foundation

/// Represents body parts that can sustain injuries in the game.
///
/// The body part values map directly to widget IDs in the injuries dialog:
/// - `"head"` → `.head`
/// - `"leftArm"` → `.leftArm` (camelCase in widget IDs)
/// - etc.
///
/// ## Widget ID Mapping
///
/// Progress bars use the raw value directly:
/// ```xml
/// <progressBar id="head" value="3"/>
/// ```
///
/// Radio buttons append "Scar" or "Nerve" suffixes:
/// ```xml
/// <radio id="headScar" checked="true"/>
/// <radio id="leftArmNerve" checked="true"/>
/// ```
///
/// ## SwiftUI Integration
///
/// Use `CaseIterable` to iterate over all body parts:
/// ```swift
/// ForEach(BodyPart.allCases, id: \.self) { bodyPart in
///     BodyPartRow(bodyPart: bodyPart)
/// }
/// ```
public enum BodyPart: String, CaseIterable, Sendable {
    case head
    case neck
    case leftArm
    case rightArm
    case chest
    case abdomen
    case back
    case leftHand
    case rightHand
    case leftLeg
    case rightLeg
}
