const fs = require('fs');
let code = fs.readFileSync('rpg-tracker/rpg-tracker/Services/FirebaseService.swift', 'utf8');

// Add listenToAuth
const initTarget = `        loadMockLeaderboards()
    }`;
const initReplace = `        loadMockLeaderboards()
        
        AuthManager.shared.$currentUser
            .compactMap { $0 }
            .sink { [weak self] user in
                self?.startListeningToCharacter(uid: user.uid)
            }
            .store(in: &cancellables)
    }
    
    private var characterListener: ListenerRegistration?
    
    func startListeningToCharacter(uid: String) {
        characterListener?.remove()
        characterListener = Firestore.firestore().collection("users").document(uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let snapshot = snapshot else { return }
                
                if snapshot.exists {
                    do {
                        let char = try snapshot.data(as: Character.self)
                        // Only update if not currently fighting to avoid UI jumps, or just update directly
                        DispatchQueue.main.async {
                            self.currentCharacter = char
                            // Backup to disk
                            if let data = try? JSONEncoder().encode(char) {
                                UserDefaults.standard.set(data, forKey: "saved_character")
                            }
                        }
                    } catch {
                        print("Error decoding character: \\(error)")
                    }
                } else if let char = self.currentCharacter {
                    // Upload local character to Firestore
                    var newChar = char
                    newChar.id = uid
                    try? Firestore.firestore().collection("users").document(uid).setData(from: newChar)
                }
            }
    }`;
code = code.replace(initTarget, initReplace);

// Add write to Firestore in syncCharacter
const syncTarget = `    func syncCharacter(_ character: Character) {
        self.currentCharacter = character
        saveCharacterToDisk()
        // In a real app: Firestore.firestore().collection("users").document(character.id).setData(from: character)
    }`;
const syncReplace = `    func syncCharacter(_ character: Character) {
        self.currentCharacter = character
        saveCharacterToDisk()
        
        // Write to Firestore!
        if character.id != "local_mock_user" {
            try? Firestore.firestore().collection("users").document(character.id).setData(from: character)
        }
    }`;
code = code.replace(syncTarget, syncReplace);

fs.writeFileSync('rpg-tracker/rpg-tracker/Services/FirebaseService.swift', code);
console.log("Connected FirebaseService to Firestore");
