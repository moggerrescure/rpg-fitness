content = File.read('rpg-tracker/rpg-tracker/rpg-tracker.entitlements')
unless content.include?('com.apple.developer.applesignin')
  insertion = "    <key>com.apple.developer.applesignin</key>\n    <array>\n        <string>Default</string>\n    </array>\n"
  content.sub!("</dict>", insertion + "</dict>")
  File.write('rpg-tracker/rpg-tracker/rpg-tracker.entitlements', content)
end
puts "Entitlements updated."
