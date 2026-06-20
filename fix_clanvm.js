const fs = require('fs');
let code = fs.readFileSync('rpg-tracker/rpg-tracker/ViewModels/ClanVM.swift', 'utf8');

const target = `    private func checkWarEnd() {`;
const replace = `    private func checkWarEnd() {
        // Now handled 100% by Cloud Functions! No more client-side fallback.
        return;`;
code = code.replace(target, replace);

fs.writeFileSync('rpg-tracker/rpg-tracker/ViewModels/ClanVM.swift', code);
console.log("Removed client-side fallback in ClanVM");
