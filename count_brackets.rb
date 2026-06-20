file = File.read('rpg-tracker/rpg-tracker/Views/PlayerProfileView.swift')
lines = file.split("\n")

depth = 0
lines.each_with_index do |line, index|
  depth += line.count('{')
  depth -= line.count('}')
  
  if index >= 790 && index <= 820
    puts "#{index + 1}: [#{depth}] #{line}"
  end
  
  if depth < 0
    puts "NEGATIVE DEPTH at line #{index + 1}: #{line}"
    break
  end
end
