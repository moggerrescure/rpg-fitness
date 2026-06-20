const fs = require('fs');
let code1 = fs.readFileSync('rpg-tracker/rpg-tracker/ViewModels/ClanVM.swift', 'utf8');

code1 = code1.replace(
    /private func checkWarEnd\(\) \{[\s\S]*?firebaseService\.syncClan\(clan\)[\s\S]*?\}/,
    `private func checkWarEnd() {\n        // Handled by Cloud Functions\n    }`
);
fs.writeFileSync('rpg-tracker/rpg-tracker/ViewModels/ClanVM.swift', code1);

let code2 = fs.readFileSync('rpg-tracker/rpg-tracker/Services/FirebaseService.swift', 'utf8');
code2 = code2.replace(
    /private func loadMockLeaderboards\(\) \{[\s\S]*?self\.leaderboards \= \[\n            "global": sorted,\n            "friends": Array\(sorted\.prefix\(5\)\)\n        \]\n    \}/,
    ``
);
fs.writeFileSync('rpg-tracker/rpg-tracker/Services/FirebaseService.swift', code2);
console.log("Cleaned dead mock code");
