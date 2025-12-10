//
//  WelcomeExampleView.swift
//  SwiftSnapshotDocumentationExamples
//
//  Created by Sasha Riabchuk on 09.12.2025.
//

import SwiftUI

/// Example welcome screen for demonstration purposes.
public struct WelcomeExampleView: View {
    public init() {}

    public var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // App icon placeholder
                Image(systemName: "app.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .foregroundStyle(.white)
                    .shadow(radius: 10)

                VStack(spacing: 16) {
                    Text("Welcome to MyApp")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Your journey starts here")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.9))
                }

                Spacer()

                // Action button
                Button {
                    // Action
                } label: {
                    Text("Get Started")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.2))
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }
}

#Preview {
    WelcomeExampleView()
}
