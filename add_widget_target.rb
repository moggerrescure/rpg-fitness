require 'xcodeproj'

project_path = 'rpg-tracker/rpg-tracker.xcodeproj'
project = Xcodeproj::Project.open(project_path)

main_target = project.targets.find { |t| t.name == 'rpg-tracker' }
if main_target.nil?
  puts "Error: Main target 'rpg-tracker' not found."
  exit 1
end

# 1. Get or Create the Widget Extension Target
widget_target = project.targets.find { |t| t.name == 'FitRPGWidget' }
if widget_target.nil?
  puts "Creating FitRPGWidget target..."
  widget_target = project.new_target(:app_extension, 'FitRPGWidget', :ios, '16.2')
else
  puts "Target 'FitRPGWidget' already exists. Re-configuring..."
end

# 2. Clean up ALL existing build files in the widget target to avoid duplicates
widget_target.source_build_phase.files.to_a.each do |f|
  widget_target.source_build_phase.remove_build_file(f)
end

# 3. Clean up ALL existing file references to widget files in the project to avoid duplicates
project.objects.select { |o| 
  o.isa == 'PBXFileReference' && 
  (o.path&.end_with?('FitRPGWidget.swift') || o.name == 'FitRPGWidget.swift' || 
   o.path&.end_with?('LiveActivityAttributes.swift') || o.name == 'LiveActivityAttributes.swift' ||
   o.path&.end_with?('FitRPGWidget-Info.plist') || o.name == 'FitRPGWidget-Info.plist')
}.each do |ref|
  puts "Removing old file reference: #{ref.path}"
  ref.remove_from_project
end

# Remove old groups if any
old_group = project.main_group.find_subpath('FitRPGWidgetSources', false)
if old_group
  old_group.remove_from_project
end

# 4. Create fresh group and file references relative to the project directory
widget_group = project.main_group.find_subpath('FitRPGWidgetSources', true)
widget_file_ref = widget_group.new_file('FitRPGWidget/FitRPGWidget.swift')
attr_file_ref = widget_group.new_file('rpg-tracker/Models/LiveActivityAttributes.swift')
plist_file_ref = widget_group.new_file('FitRPGWidget/FitRPGWidget-Info.plist')

# 5. Associate files with Widget Target Compile Sources
widget_target.source_build_phase.add_file_reference(widget_file_ref)
widget_target.source_build_phase.add_file_reference(attr_file_ref)

# 6. Get Main Target Bundle ID
main_bundle_id = nil
main_target.build_configurations.each do |config|
  main_bundle_id ||= config.build_settings['PRODUCT_BUNDLE_IDENTIFIER']
end
main_bundle_id ||= 'moggerrescure.rpg-fitness'
widget_bundle_id = "#{main_bundle_id}.FitRPGWidget"
puts "Main Target Bundle ID: #{main_bundle_id}"
puts "Widget Target Bundle ID: #{widget_bundle_id}"

# 7. Configure Widget Target Build Settings
widget_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_NAME'] = 'FitRPGWidget'
  config.build_settings['WRAPPER_EXTENSION'] = 'appex'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = widget_bundle_id
  config.build_settings['INFOPLIST_FILE'] = 'FitRPGWidget/FitRPGWidget-Info.plist'
  config.build_settings['GENERATE_INFOPLIST'] = 'NO'
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.2'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'
end

# Ensure product reference path is set correctly
if widget_target.product_reference
  widget_target.product_reference.path = 'FitRPGWidget.appex'
  widget_target.product_reference.name = 'FitRPGWidget.appex'
end

# 8. Enable NSSupportsLiveActivities on Main Target Build Settings
main_target.build_configurations.each do |config|
  config.build_settings['INFOPLIST_KEY_NSSupportsLiveActivities'] = 'YES'
end

# 9. Add Target Dependency (Main Target -> Widget Target)
unless main_target.dependencies.any? { |dep| dep.target == widget_target }
  main_target.add_dependency(widget_target)
end

# 10. Embed Widget Target Product in Main Target App Extensions Copy Phase
embed_phase = main_target.copy_files_build_phases.find { |p| p.symbol_dst_subfolder_spec == :plug_ins }
if embed_phase.nil?
  embed_phase = main_target.new_copy_files_build_phase('Embed App Extensions')
  embed_phase.symbol_dst_subfolder_spec = :plug_ins
end

unless embed_phase.files.any? { |f| f.file_ref == widget_target.product_reference }
  embed_phase.add_file_reference(widget_target.product_reference)
end

# Save Project changes
project.save
puts "Successfully configured Xcode project for Live Activities and FitRPGWidget extension target."
