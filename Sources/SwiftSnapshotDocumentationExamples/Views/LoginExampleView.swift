//
//  LoginExampleView.swift
//  SwiftSnapshotDocumentationExamples
//
//  Created by Sasha Riabchuk on 09.12.2025.
//

import SwiftUI

/// Example login screen for demonstration purposes.
public struct LoginExampleView: View {
    @State private var email = ""
    @State private var password = ""

    public init() {}

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .foregroundStyle(.blue)
                            .padding(.top, 40)

                        Text("Sign In")
                            .font(.system(size: 32, weight: .bold))

                        Text("Welcome back! Please sign in to continue.")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 16)

                    // Form fields
                    VStack(spacing: 16) {
                        // Email field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)

                            TextField("Enter your email", text: $email)
                                #if os(iOS)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                #endif
                                .autocorrectionDisabled()
                                .textFieldStyle(.roundedBorder)
                        }

                        // Password field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)

                            SecureField("Enter your password", text: $password)
                                .textFieldStyle(.roundedBorder)
                                #if os(iOS)
                                .textContentType(.password)
                                #endif
                        }

                        // Forgot password
                        HStack {
                            Spacer()
                            Button("Forgot Password?") {
                                // Action
                            }
                            .font(.system(size: 14))
                        }
                    }
                    .padding(.horizontal, 24)

                    // Sign in button
                    Button {
                        // Action
                    } label: {
                        Text("Sign In")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                        Text("OR")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)

                    // Social sign in
                    Button {
                        // Action
                    } label: {
                        HStack {
                            Image(systemName: "applelogo")
                            Text("Sign in with Apple")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.black)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}

#Preview {
    LoginExampleView()
}
