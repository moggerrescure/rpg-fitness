const fs = require('fs');
let code = fs.readFileSync('rpg-tracker/rpg-tracker/Services/FirebaseService.swift', 'utf8');

const importTarget = `import Combine`;
const importReplace = `import Combine\nimport FirebaseFunctions\nimport FirebaseFirestore\nimport FirebaseAuth`;
code = code.replace(importTarget, importReplace);

const resolveTarget = `    // MARK: - Clan Operations`;
const resolveReplace = `    // MARK: - Server Integrations
    func resolvePvEBattle(won: Bool, bossLootChance: Double, xp: Int, gold: Int, completion: @escaping (String?) -> Void) {
        let functions = Functions.functions()
        functions.httpsCallable("resolvePvEBattle").call([
            "won": won,
            "bossLootChance": bossLootChance,
            "xp": xp,
            "gold": gold
        ]) { result, error in
            if let error = error {
                print("Error resolving PvE battle on server: \\(error)")
                completion(nil)
                return
            }
            if let data = result?.data as? [String: Any],
               let droppedItemId = data["droppedItemId"] as? String {
                completion(droppedItemId)
            } else {
                completion(nil)
            }
        }
    }

    // MARK: - Clan Operations`;
code = code.replace(resolveTarget, resolveReplace);

fs.writeFileSync('rpg-tracker/rpg-tracker/Services/FirebaseService.swift', code);
console.log("Added resolvePvEBattle");
