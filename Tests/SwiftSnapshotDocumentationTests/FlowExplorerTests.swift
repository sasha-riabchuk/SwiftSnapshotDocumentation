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

@Test func documentedScreenStoresTransitions() {
    let screen = DocumentedScreen(
        title: "Login",
        description: "Auth",
        devices: [],
        themes: [],
        transitions: [.to("Success", on: "valid"), .to("Error", on: "invalid")]
    )
    #expect(screen.transitions.count == 2)
    #expect(screen.transitions.first?.target == "Success")
    #expect(screen.transitions.last?.target == "Error")
}

private func screenStub(_ title: String, _ transitions: [ScreenTransition] = []) -> DocumentedScreen {
    DocumentedScreen(title: title, description: "d", devices: [], themes: [], transitions: transitions)
}

@Test func edgeResolverFallsBackToLinearWhenNoTransitions() {
    let screens = [screenStub("Welcome"), screenStub("Login"), screenStub("Profile")]
    let result = FlowEdgeResolver.resolve(screens: screens)
    #expect(result.edges == [
        .init(from: "welcome", to: "login", label: nil),
        .init(from: "login", to: "profile", label: nil),
    ])
    #expect(result.unresolved.isEmpty)
}

@Test func edgeResolverUsesExplicitTransitionsOnly() {
    let screens = [
        screenStub("Login", [.to("Success", on: "valid"), .to("Error", on: "invalid")]),
        screenStub("Success"),
        screenStub("Error"),
    ]
    let result = FlowEdgeResolver.resolve(screens: screens)
    #expect(result.edges == [
        .init(from: "login", to: "success", label: "valid"),
        .init(from: "login", to: "error", label: "invalid"),
    ])
    #expect(result.unresolved.isEmpty)
}

@Test func edgeResolverReportsUnresolvedTargetsAndSkipsThem() {
    let screens = [screenStub("Login", [.to("Nowhere")]), screenStub("Home")]
    let result = FlowEdgeResolver.resolve(screens: screens)
    #expect(result.edges.isEmpty)
    #expect(result.unresolved == ["Login → Nowhere"])
}

@Test func edgeResolverResolvesTargetBySanitizedTitle() {
    let screens = [
        DocumentedScreen(title: "Home", description: "d", devices: [], themes: [], transitions: [.to("sign-up")]),
        DocumentedScreen(id: "custom", title: "Sign Up", description: "d", devices: [], themes: []),
    ]
    let result = FlowEdgeResolver.resolve(screens: screens)
    #expect(result.edges == [.init(from: "home", to: "custom", label: nil)])
    #expect(result.unresolved.isEmpty)
}
