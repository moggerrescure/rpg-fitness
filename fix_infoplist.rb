require 'xcodeproj'

project_path = 'rpg-tracker/rpg-tracker.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 1. Project level
project.build_configurations.each do |config|
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
end

# 2. Target level
project.targets.each do |target|
  target.build_configurations.each do |config|
    config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  end
end

project.save
puts "Successfully enforced GENERATE_INFOPLIST_FILE = YES on all configurations."
