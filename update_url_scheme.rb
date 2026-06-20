require 'xcodeproj'

project_path = 'rpg-tracker/rpg-tracker.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

client_id = 'com.googleusercontent.apps.667537183554-7qepnov5fh8erlq0kl97tb951i5pkpie'
target.build_configurations.each do |config|
  config.build_settings['INFOPLIST_KEY_CFBundleURLTypes'] = %Q{(
    {
      CFBundleTypeRole = Editor;
      CFBundleURLSchemes = (
        "#{client_id}",
      );
    }
  )}
end

project.save
puts "URL Scheme updated to match NEW GoogleService-Info.plist."
