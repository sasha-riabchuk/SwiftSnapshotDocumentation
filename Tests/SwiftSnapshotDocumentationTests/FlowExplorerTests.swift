import Testing
import Foundation
@testable import SwiftSnapshotDocumentation

@Test func screenTransitionFactorySetsTargetAndLabel() {
    let t1 = ScreenTransition.to("Success", on: "valid")
    #expect(t1.target == "Success")
    #expect(t1.label == "valid")

    let t2 = ScreenTransition.to("Home")
    #expect(t2.target == "Home")
    #expect(t2.label == nil)
}
