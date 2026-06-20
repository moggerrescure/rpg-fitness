content = File.read('rpg-tracker/rpg-tracker/Views/PlayerProfileView.swift')
content = content.gsub('.frame(maxWidth: .infinity, alignment: .center)olor(Theme.danger)', '.frame(maxWidth: .infinity, alignment: .center)')
File.write('rpg-tracker/rpg-tracker/Views/PlayerProfileView.swift', content)
