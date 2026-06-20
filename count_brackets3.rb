file = File.read('rpg-tracker/rpg-tracker/Views/PlayerProfileView.swift')
lines = file.split("\n")

depth = 0
struct_depth = 0
body_depth = 0

lines.each_with_index do |line, index|
  if line.include?('struct PlayerProfileView: View {')
    struct_depth = depth + 1
  end
  if line.include?('var body: some View {')
    body_depth = depth + 1
  end

  depth += line.count('{')
  depth -= line.count('}')
  
  if index >= 30 && index <= 810
    if depth < body_depth && depth >= struct_depth
       puts "BODY CLOSED at line #{index + 1}: #{line}"
    end
    if depth < struct_depth
       puts "STRUCT CLOSED at line #{index + 1}: #{line}"
       break
    end
  end
end
