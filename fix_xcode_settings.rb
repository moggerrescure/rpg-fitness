require 'xcodeproj'

project_path = 'rpg-tracker/rpg-tracker.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

target.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'rpg-tracker/rpg-tracker.entitlements'
  
  infoplist_key = 'INFOPLIST_KEY_UIBackgroundModes'
  if config.build_settings[infoplist_key]
    modes = config.build_settings[infoplist_key].to_s.split(',').map(&:strip)
    unless modes.include?('remote-notification')
      modes << 'remote-notification'
      config.build_settings[infoplist_key] = modes.join(', ')
    end
  else
    config.build_settings[infoplist_key] = 'remote-notification'
  end
end

project.save
puts "Updated Build Settings!"
