#!/usr/bin/env ruby
# Generates HostApp/GlassProof.xcodeproj: a minimal iOS app + a host-based unit-test
# target, so tests run inside a real running app (real UIApplication/scene/key window).
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
app.add_file_references([app_group.new_file(File.join(root, "Sources/App/GlassProofApp.swift"))])

# --- Host-based test target ---
tests = project.new_target(:unit_test_bundle, "GlassProofTests", :ios, "17.0")
tests.build_configurations.each do |c|
  c.build_settings.merge!(common)
  c.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.example.GlassProofTests"
  c.build_settings["TEST_HOST"] = "$(BUILT_PRODUCTS_DIR)/GlassProofApp.app/GlassProofApp"
  c.build_settings["BUNDLE_LOADER"] = "$(TEST_HOST)"
end
tests_group = project.main_group.new_group("Tests")
tests.add_file_references([tests_group.new_file(File.join(root, "Sources/Tests/GlassProofTests.swift"))])
tests.add_dependency(app)

# --- Local Swift package (the parent SPM package) linked into the test target ---
local_ref = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
local_ref.relative_path = ".."
project.root_object.package_references << local_ref

["SwiftSnapshotDocumentation"].each do |product|
  dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dep.package = local_ref
  dep.product_name = product
  tests.package_product_dependencies << dep
  bf = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  bf.product_ref = dep
  tests.frameworks_build_phase.files << bf
end

project.save

# --- Shared scheme so `xcodebuild test` can find it ---
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.add_test_target(tests)
scheme.set_launch_target(app)
scheme.save_as(proj_path, "GlassProofApp", true)

puts "generated #{proj_path}"
