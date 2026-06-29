import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

class ClassSelectionVM: ObservableObject {
    @Published var username: String = ""
    @Published var selectedClass: CharacterClass = .swordsman
    @Published var isSubmitting: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""

    private let firebaseService = FirebaseService.shared

    var selectedWeapon: EquipmentItem? {
        EquipmentItem.starterWeapons[selectedClass]
    }

    var selectedArmor: EquipmentItem? {
        EquipmentItem.starterArmors[selectedClass]
    }

    func confirmSelection(completion: @escaping (Bool) -> Void) {
        let cleanName = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            errorMessage = "Please enter a valid character name."
            showError = true
            return
        }

        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "Not connected to server. Please check your internet connection."
            showError = true
            return
        }

        isSubmitting = true
        showError = false

        Task { @MainActor [weak self] in
            guard let self = self else { return }

            // Check if username is already taken
            let db = Firestore.firestore()
            do {
                let existing = try await db.collection("users")
                    .whereField("username", isEqualTo: cleanName)
                    .limit(to: 1)
                    .getDocuments()

                if !existing.documents.isEmpty {
                    self.isSubmitting = false
                    self.errorMessage = "This name is already taken. Please choose another."
                    self.showError = true
                    return
                }
            } catch {
                // If the check fails, proceed anyway (offline tolerance)
                print("Username uniqueness check failed: \(error)")
            }

            let defaultWeapon = EquipmentItem.starterWeapons[self.selectedClass]
            let defaultArmor = EquipmentItem.starterArmors[self.selectedClass]

            // Use real Firebase UID as character ID — this links the character to the Firebase account
            let newChar = Character(
                id: uid,
                username: cleanName,
                selectedClass: self.selectedClass,
                level: 1,
                xp: 0,
                gold: 100,
                energy: 100,
                maxEnergy: 100,
                basePower: 100,
                stats: CharacterStats(),
                equippedWeaponId: defaultWeapon?.id,
                equippedArmorId: defaultArmor?.id,
                clanId: nil
            )

            // Save to Firestore — this will trigger the snapshot listener in FirebaseService
            // and automatically update currentCharacter
            do {
                try db.collection("users").document(uid).setData(from: newChar)
                self.isSubmitting = false
                completion(true)
            } catch {
                self.isSubmitting = false
                self.errorMessage = "Failed to save your character. Please try again."
                self.showError = true
                print("Error saving character to Firestore: \(error)")
            }
        }
    }
}
