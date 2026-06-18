import Foundation
import Combine

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
        
        isSubmitting = true
        showError = false
        
        // Simulating network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self = self else { return }
            self.isSubmitting = false
            
            // Build custom character
            let defaultWeapon = EquipmentItem.starterWeapons[self.selectedClass]
            let defaultArmor = EquipmentItem.starterArmors[self.selectedClass]
            
            let newChar = Character(
                id: UUID().uuidString,
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
            
            self.firebaseService.syncCharacter(newChar)
            completion(true)
        }
    }
}
