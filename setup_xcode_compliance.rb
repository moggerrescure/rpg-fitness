require 'xcodeproj'

project_path = 'rpg-tracker/rpg-tracker.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 1. Create PrivacyInfo.xcprivacy
privacy_content = <<~PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeFitness</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <true/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeName</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <true/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
    </array>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
PLIST
File.write('rpg-tracker/rpg-tracker/PrivacyInfo.xcprivacy', privacy_content)

# 2. Create entitlements
entitlements_content = <<~PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>aps-environment</key>
    <string>development</string>
</dict>
</plist>
PLIST
File.write('rpg-tracker/rpg-tracker/rpg-tracker.entitlements', entitlements_content)

# 3. Add files to Xcode project
target = project.targets.first
group = project.main_group.find_subpath(File.join('rpg-tracker'), true)

unless group.files.find { |f| f.path == 'PrivacyInfo.xcprivacy' }
  file_ref = group.new_file('PrivacyInfo.xcprivacy')
  target.resources_build_phase.add_file_reference(file_ref)
end

unless group.files.find { |f| f.path == 'rpg-tracker.entitlements' }
  group.new_file('rpg-tracker.entitlements')
end

# 4. Update Build Settings
target.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'rpg-tracker/rpg-tracker.entitlements'
  
  # Ensure Push Notifications background mode
  infoplist_key = 'INFOPLIST_KEY_UIBackgroundModes'
  if config.build_settings[infoplist_key]
    modes = config.build_settings[infoplist_key].split(',').map(&:strip)
    unless modes.include?('remote-notification')
      modes << 'remote-notification'
      config.build_settings[infoplist_key] = modes.join(', ')
    end
  else
    config.build_settings[infoplist_key] = 'remote-notification'
  end
end

project.save
puts "Successfully configured Xcode project for Apple Review readiness."
