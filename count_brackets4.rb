file = File.read('rpg-tracker/rpg-tracker/Views/PlayerProfileView.swift')
lines = file.split("\n")

depth = 0
lines.each_with_index do |line, index|
  depth += line.count('{')
  depth -= line.count('}')
  if index == 796
    puts "Depth at 797 is #{depth}"
  end
end
