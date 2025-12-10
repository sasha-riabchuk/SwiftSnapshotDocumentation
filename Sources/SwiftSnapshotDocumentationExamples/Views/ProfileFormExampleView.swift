//
//  ProfileFormExampleView.swift
//  SwiftSnapshotDocumentationExamples
//
//  Created by Sasha Riabchuk on 09.12.2025.
//

import SwiftUI

/// Example profile form for demonstration purposes.
public struct ProfileFormExampleView: View {
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var isLoading = false

    public init(firstName: String = "", lastName: String = "", isLoading: Bool = false) {
        _firstName = State(initialValue: firstName)
        _lastName = State(initialValue: lastName)
        _isLoading = State(initialValue: isLoading)
    }

    public var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Help us personalize your experience")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Personal Information")
                }

                Section {
                    TextField("First Name", text: $firstName)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif
                        .autocorrectionDisabled()
                        .disabled(isLoading)

                    TextField("Last Name", text: $lastName)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif
                        .autocorrectionDisabled()
                        .disabled(isLoading)
                }

                Section {
                    Button {
                        // Action
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text("Continue")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                    }
                    .disabled(firstName.isEmpty || lastName.isEmpty || isLoading)
                }
            }
            .navigationTitle("Your Profile")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
    }
}

#Preview("Empty") {
    ProfileFormExampleView()
}

#Preview("Filled") {
    ProfileFormExampleView(firstName: "John", lastName: "Doe")
}

#Preview("Loading") {
    ProfileFormExampleView(firstName: "John", lastName: "Doe", isLoading: true)
}
