#!/usr/bin/env ruby
# Generates HostApp/GlassProof.xcodeproj: a minimal iOS app that presents a glass screen by
# launch argument, plus a UI-test target that captures the true framebuffer via
# XCUIScreen.screenshot() (pixel-exact glass, unlike an in-process drawHierarchy capture).
require "xcodeproj"

root = File.dirname(__FILE__)
proj_path = File.join(root, "GlassProof.xcodeproj")
project = Xcodeproj::Project.new(proj_path)

common = {
  "IPHONEOS_DEPLOYMENT_TARGET" => "17.0",
  "SWIFT_VERSION" => "5.0",
  "CODE_SIGNING_ALLOWED" => "NO",
  "CODE_SIGNING_REQUIRED" => "NO",
  "TARGETED_DEVICE_FAMILY" => "1,2",
  "GENERATE_INFOPLIST_FILE" => "YES",
}

# --- App target ---
app = project.new_target(:application, "GlassProofApp", :ios, "17.0")
app.build_configurations.each do |c|
  c.build_settings.merge!(common)
  c.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.example.GlassProofApp"
  c.build_settings["INFOPLIST_KEY_UIApplicationSceneManifest_Generation"] = "YES"
  c.build_settings["INFOPLIST_KEY_UILaunchScreen_Generation"] = "YES"
  c.build_settings["INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents"] = "YES"
end
app_group = project.main_group.new_group("App")
app.add_file_references([
  app_group.new_file(File.join(root, "Sources/App/GlassProofApp.swift")),
  app_group.new_file(File.join(root, "Sources/App/GlassScreens.swift")),
])

# --- UI test target (drives the app, captures the framebuffer) ---
ui = project.new_target(:ui_test_bundle, "GlassProofUITests", :ios, "17.0")
ui.build_configurations.each do |c|
  c.build_settings.merge!(common)
  c.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.example.GlassProofUITests"
  c.build_settings["TEST_TARGET_NAME"] = "GlassProofApp"
end
ui_group = project.main_group.new_group("UITests")
ui.add_file_references([ui_group.new_file(File.join(root, "Sources/UITests/GlassUITests.swift"))])
ui.add_dependency(app)

project.save

# --- Shared scheme so `xcodebuild test` finds the UI tests ---
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.add_test_target(ui)
scheme.set_launch_target(app)
scheme.save_as(proj_path, "GlassProofApp", true)

puts "generated #{proj_path}"
