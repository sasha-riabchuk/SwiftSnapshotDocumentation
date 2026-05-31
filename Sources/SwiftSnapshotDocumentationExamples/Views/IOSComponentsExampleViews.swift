//
//  IOSComponentsExampleViews.swift
//  SwiftSnapshotDocumentationExamples
//
//  Demo views for native iOS components. Overlay components (alert, sheets, popover,
//  action sheet, toast) are rendered INLINE as their presented appearance, because
//  swift-snapshot-testing captures the SwiftUI view hierarchy and native presentations
//  live in a separate UIKit window. TabView / NavigationStack are used for real.
//  All use semantic colors so light and dark snapshots both look correct.
//

import SwiftUI

// MARK: - Shared backdrop

/// A faint "app screen" used behind overlay components for context.
private struct BackdropScreen: View {
    var title: String = "Library"
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.largeTitle.bold())
                .padding(.horizontal, 20)
                .padding(.top, 64)
                .padding(.bottom, 12)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(0..<10) { i in
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                                .frame(width: 44, height: 44)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Item \(i + 1)").font(.body)
                                Text("Supporting text").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 11)
                        Divider().padding(.leading, 76)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.systemBackground))
    }
}

private struct Dim: View {
    var body: some View { Color.black.opacity(0.28).ignoresSafeArea() }
}

// MARK: - Alert

public struct AlertComponentView: View {
    public init() {}
    public var body: some View {
        ZStack {
            BackdropScreen()
            Dim()
            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("Delete “Project”?").font(.headline)
                    Text("This item will be permanently deleted. This action cannot be undone.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16).padding(.top, 19).padding(.bottom, 16)
                Divider()
                HStack(spacing: 0) {
                    Text("Cancel").frame(maxWidth: .infinity)
                    Divider().frame(height: 44)
                    Text("Delete").foregroundStyle(.red).fontWeight(.semibold).frame(maxWidth: .infinity)
                }
                .font(.body).frame(height: 44)
            }
            .frame(width: 270)
            .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - Action sheet (confirmation dialog)

public struct ActionSheetComponentView: View {
    public init() {}
    public var body: some View {
        ZStack(alignment: .bottom) {
            BackdropScreen()
            Dim()
            VStack(spacing: 8) {
                VStack(spacing: 0) {
                    sheetRow("Take Photo", color: .blue)
                    Divider()
                    sheetRow("Choose from Library", color: .blue)
                    Divider()
                    sheetRow("Remove Photo", color: .red)
                }
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                Text("Cancel").fontWeight(.semibold).foregroundStyle(.blue)
                    .frame(maxWidth: .infinity).frame(height: 57)
                    .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 10).padding(.bottom, 12)
        }
    }
    private func sheetRow(_ title: String, color: Color) -> some View {
        Text(title).foregroundStyle(color).frame(maxWidth: .infinity).frame(height: 57).font(.body)
    }
}

// MARK: - Half sheet (medium detent)

public struct HalfSheetComponentView: View {
    public init() {}
    public var body: some View {
        ZStack(alignment: .bottom) {
            BackdropScreen()
            Color.black.opacity(0.12).ignoresSafeArea()
            VStack(spacing: 0) {
                Capsule().fill(Color(.systemGray3)).frame(width: 36, height: 5).padding(.top, 6).padding(.bottom, 14)
                Text("New Reminder").font(.title3.bold()).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                VStack(spacing: 0) {
                    field("Title", "Buy groceries")
                    Divider().padding(.leading, 16)
                    field("Notes", "Milk, eggs, bread")
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                .padding(20)
                Spacer()
                Text("Add").fontWeight(.semibold).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 420)
            .background(Color(.systemBackground), in: UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))
        }
    }
    private func field(_ label: String, _ value: String) -> some View {
        HStack { Text(label).foregroundStyle(.secondary); Spacer(); Text(value) }
            .padding(.horizontal, 16).frame(height: 48)
    }
}

// MARK: - Full-screen cover

public struct FullScreenCoverComponentView: View {
    public init() {}
    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Cancel").foregroundStyle(.blue)
                Spacer()
                Text("New Message").font(.headline)
                Spacer()
                Text("Send").fontWeight(.semibold).foregroundStyle(.blue)
            }
            .padding(.horizontal, 16).padding(.top, 60).padding(.bottom, 12)
            Divider()
            VStack(spacing: 0) {
                composeRow("To:", "Jane Appleseed")
                Divider().padding(.leading, 16)
                composeRow("Subject:", "Lunch on Friday?")
            }
            Divider()
            Text("Hi Jane,\n\nAre you free for lunch this Friday around noon? There's a new place near the office I've been wanting to try.\n\nBest,\nAlex")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    private func composeRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 8) { Text(label).foregroundStyle(.secondary); Text(value); Spacer() }
            .padding(.horizontal, 16).frame(height: 46)
    }
}

// MARK: - Popover

public struct PopoverComponentView: View {
    public init() {}
    public var body: some View {
        ZStack(alignment: .top) {
            BackdropScreen(title: "Photo")
            Color.black.opacity(0.06).ignoresSafeArea()
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    popRow("Copy", "doc.on.doc")
                    Divider()
                    popRow("Duplicate", "plus.square.on.square")
                    Divider()
                    popRow("Share…", "square.and.arrow.up")
                    Divider()
                    popRow("Delete", "trash", color: .red)
                }
                .frame(width: 230)
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 120).padding(.trailing, 24)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
    private func popRow(_ title: String, _ icon: String, color: Color = .primary) -> some View {
        HStack { Text(title).foregroundStyle(color); Spacer(); Image(systemName: icon).foregroundStyle(color) }
            .padding(.horizontal, 14).frame(height: 44).font(.callout)
    }
}

// MARK: - Tab bar (real TabView)

public struct TabBarComponentView: View {
    public init() {}
    public var body: some View {
        TabView(selection: .constant(1)) {
            placeholder("Today").tabItem { Label("Today", systemImage: "calendar") }.tag(0)
            placeholder("Browse").tabItem { Label("Browse", systemImage: "square.grid.2x2.fill") }.tag(1)
            placeholder("Search").tabItem { Label("Search", systemImage: "magnifyingglass") }.tag(2)
            placeholder("Profile").tabItem { Label("Profile", systemImage: "person.crop.circle") }.tag(3)
        }
    }
    private func placeholder(_ title: String) -> some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            VStack(spacing: 10) {
                Image(systemName: "square.grid.2x2.fill").font(.system(size: 44)).foregroundStyle(.blue)
                Text(title).font(.largeTitle.bold())
            }
        }
    }
}

// MARK: - Navigation bar (real NavigationStack)

public struct NavBarComponentView: View {
    public init() {}
    public var body: some View {
        NavigationStack {
            List {
                Section("General") {
                    navRow("Airplane Mode", "airplane", tint: .orange)
                    navRow("Wi-Fi", "wifi", tint: .blue, value: "Home")
                    navRow("Bluetooth", "antenna.radiowaves.left.and.right", tint: .blue, value: "On")
                }
                Section("Display") {
                    navRow("Appearance", "circle.lefthalf.filled", tint: .indigo, value: "Auto")
                    navRow("Text Size", "textformat.size", tint: .gray)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Image(systemName: "magnifyingglass") }
                ToolbarItem(placement: .topBarLeading) { Image(systemName: "person.crop.circle") }
            }
        }
    }
    private func navRow(_ title: String, _ icon: String, tint: Color, value: String = "") -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(.white).frame(width: 29, height: 29)
                .background(tint, in: RoundedRectangle(cornerRadius: 7))
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Toast / banner

public struct ToastComponentView: View {
    public init() {}
    public var body: some View {
        ZStack(alignment: .top) {
            BackdropScreen(title: "Inbox")
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Message sent").font(.subheadline.weight(.semibold))
                    Text("Your reply was delivered.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color(.tertiarySystemBackground), in: Capsule())
            .overlay(Capsule().strokeBorder(Color(.separator).opacity(0.4)))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
            .padding(.horizontal, 16).padding(.top, 56)
        }
    }
}
