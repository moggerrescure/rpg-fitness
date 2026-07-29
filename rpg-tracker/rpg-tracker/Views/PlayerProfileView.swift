import SwiftUI
import HealthKit
import GoogleSignIn
import FirebaseAuth

struct PlayerProfileView: View {
    @ObservedObject var firebaseService = FirebaseService.shared
    @ObservedObject private var authManager = AuthManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var profileToastMessage: String? = nil
    @State private var showArmoryShop = false
    @State private var isEditingUsername = false
    @State private var usernameInput = ""
    @State private var showAvatarSelector = false
    @State private var showInventory = false
    @State private var showConstellations = false
    @State private var isProcessingAccountAction = false
    @State private var showDeleteAccountAlert = false
    @State private var showDeleteAccountError = false
    @State private var deleteAccountError: String? = nil
    @State private var authErrorMessage: String? = nil
    @State private var showAccountDeletedConfirmation = false
    @State private var presentedLegalDocument: LegalDocumentRef? = nil
    @State private var isFillingScreenshotWallet = false
    @ObservedObject private var remoteConfig = RemoteConfigManager.shared
    
    init(character: Character) {
        // Direct observation of FirebaseService handles reactivity; signature kept for compatibility.
    }
    
    private var character: Character {
        firebaseService.currentCharacter ?? Character(id: "local", username: "FitnessHero", selectedClass: .archer)
    }

    private var appVersionLabel: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "FitRPG v\(version) (\(build))"
    }
    
    var equippedWeapon: EquipmentItem? {
        guard let weaponId = character.equippedWeaponId else { return nil }
        return EquipmentItem.findWeapon(by: weaponId)
    }
    
    var equippedArmor: EquipmentItem? {
        guard let armorId = character.equippedArmorId else { return nil }
        return EquipmentItem.findArmor(by: armorId)
    }
    
    var defense: Int {
        equippedArmor?.defense ?? 0
    }
    
    // Dynamic attributes based on repetition count stats
    var strength: Int {
        character.baseStrength + Int(Double(character.stats.totalPullups) * 0.5) + Int(Double(character.stats.totalPushups) * 0.3)
    }
    
    var dexterity: Int {
        character.baseDexterity + Int(Double(character.stats.totalSquats) * 0.6)
    }
    
    var vitality: Int {
        character.baseVitality + Int(Double(character.stats.totalDips) * 0.8)
    }
    
    var intelligence: Int {
        character.baseIntelligence + (character.level * 2)
    }
    
    var body: some View {
        ZStack {
            // Animated background representing grand castle clan hall
            AnimatedBackgroundView(backgroundType: .clanHall)
            
            // Subtle darken filter overlay to ensure card readability
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Top bar
                    HStack {
                        Text("HERO PROFILE")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(Theme.textMuted)
                            .tracking(1.2)
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                                .frame(width: 36, height: 36)
                                .background(Color.black.opacity(0.45))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                        }
                        .buttonStyle(TactileButtonStyle())
                        .accessibilityLabel("Close profile")
                    }
                    .padding(.horizontal)
                    .padding(.top, 14)
                    
                    // Fantasy hero header — solid card + class glow (no empty glass slab)
                    ZStack {
                        Circle()
                            .fill(character.selectedClass.themeColor.opacity(0.22))
                            .frame(width: 200, height: 200)
                            .blur(radius: 36)
                            .offset(x: -70, y: -10)
                        
                        VStack(spacing: 0) {
                            HStack(alignment: .center, spacing: 14) {
                                Button(action: { showAvatarSelector = true }) {
                                    ZStack(alignment: .bottomTrailing) {
                                        ZStack {
                                            if let avatar = character.avatarName, let uiImage = loadLocalAvatar(named: avatar) {
                                                Image(platformImage: uiImage)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 76, height: 76)
                                                    .clipShape(Circle())
                                            } else {
                                                let emblem = AvatarEmblem.all.first { $0.id == character.avatarName }
                                                let tint = emblem?.tint ?? character.selectedClass.themeColor
                                                Circle()
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [tint.opacity(0.4), Theme.secondaryCard],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                                    .frame(width: 76, height: 76)
                                                Image(systemName: emblem?.symbol ?? classIcon(for: character.selectedClass))
                                                    .font(.system(size: 28, weight: .bold))
                                                    .foregroundStyle(tint)
                                            }
                                        }
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [
                                                            character.selectedClass.themeColor,
                                                            character.selectedClass.themeColor.opacity(0.35)
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 2.5
                                                )
                                        )
                                        .glow(color: character.selectedClass.themeColor.opacity(0.45), radius: 8)
                                        
                                        Circle()
                                            .fill(character.selectedClass.themeColor)
                                            .frame(width: 24, height: 24)
                                            .overlay(
                                                Image(systemName: "pencil")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundStyle(.white)
                                            )
                                            .overlay(Circle().stroke(Theme.cardBackground, lineWidth: 2))
                                            .offset(x: 2, y: 2)
                                    }
                                }
                                .buttonStyle(TactileButtonStyle())
                                .accessibilityLabel("Change avatar")
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    if isEditingUsername {
                                        HStack(spacing: 6) {
                                            TextField("Enter username...", text: $usernameInput)
                                                .font(.system(size: 15, weight: .semibold))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 8)
                                                .background(Theme.secondaryCard)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                                .foregroundStyle(Theme.textPrimary)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(character.selectedClass.themeColor.opacity(0.55), lineWidth: 1)
                                                )
                                            
                                            Button(action: {
                                                let cleanName = usernameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                                if !cleanName.isEmpty {
                                                    var updated = character
                                                    updated.username = cleanName
                                                    firebaseService.syncCharacter(updated)
                                                    isEditingUsername = false
                                                }
                                            }) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.title3)
                                                    .foregroundStyle(Theme.success)
                                            }
                                            .buttonStyle(TactileButtonStyle())
                                            .accessibilityLabel("Save username")
                                            
                                            Button(action: { isEditingUsername = false }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.title3)
                                                    .foregroundStyle(Theme.danger)
                                            }
                                            .buttonStyle(TactileButtonStyle())
                                            .accessibilityLabel("Cancel username edit")
                                        }
                                    } else {
                                        HStack(spacing: 6) {
                                            Text(character.username.isEmpty ? "Hero" : character.username)
                                                .font(.system(size: 22, weight: .black, design: .default))
                                                .foregroundStyle(Theme.textPrimary)
                                                .lineLimit(2)
                                                .minimumScaleFactor(0.55)
                                                .truncationMode(.middle)
                                                .fixedSize(horizontal: false, vertical: true)
                                            
                                            Button(action: {
                                                usernameInput = character.username
                                                isEditingUsername = true
                                            }) {
                                                Image(systemName: "pencil.circle.fill")
                                                    .font(.system(size: 18, weight: .semibold))
                                                    .foregroundStyle(character.selectedClass.themeColor)
                                            }
                                            .buttonStyle(TactileButtonStyle())
                                            .accessibilityLabel("Edit username")
                                            .fixedSize()
                                        }
                                    }
                                    
                                    HStack(spacing: 8) {
                                        Text(character.selectedClass.rawValue.uppercased())
                                            .font(.system(size: 10, weight: .black, design: .monospaced))
                                            .foregroundStyle(character.selectedClass.themeColor)
                                            .tracking(1)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                        
                                        Text("·")
                                            .foregroundStyle(Theme.textMuted)
                                        
                                        Text("LVL \(character.level)")
                                            .font(.system(size: 10, weight: .black, design: .monospaced))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(character.selectedClass.themeColor)
                                            .clipShape(Capsule())
                                            .fixedSize()
                                    }
                                    
                                    GeometryReader { geo in
                                        let progress = min(1.0, Double(character.xp) / Double(max(1, character.xpForNextLevel)))
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Theme.secondaryCard)
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [
                                                            character.selectedClass.themeColor,
                                                            character.selectedClass.themeColor.opacity(0.65)
                                                        ],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .frame(width: geo.size.width * progress)
                                        }
                                    }
                                    .frame(height: 5)
                                    
                                    Text("\(character.xp) / \(character.xpForNextLevel) XP")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Theme.textMuted)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 14)
                            
                            Divider().background(Theme.border)
                            
                            HStack(spacing: 8) {
                                Button(action: { showAvatarSelector = true }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "person.crop.circle.badge.pencil")
                                            .font(.system(size: 11, weight: .bold))
                                        Text("AVATAR")
                                            .font(.system(size: 10, weight: .black, design: .monospaced))
                                    }
                                    .foregroundStyle(Theme.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Theme.secondaryCard.opacity(0.95))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Theme.border, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(TactileButtonStyle())
                                
                                Button(action: {
                                    usernameInput = character.username
                                    isEditingUsername = true
                                }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "textformat")
                                            .font(.system(size: 11, weight: .bold))
                                        Text("NAME")
                                            .font(.system(size: 10, weight: .black, design: .monospaced))
                                    }
                                    .foregroundStyle(Theme.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Theme.secondaryCard.opacity(0.95))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Theme.border, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(TactileButtonStyle())
                                
                                Button(action: { showArmoryShop = true }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "cart.fill")
                                            .font(.system(size: 11, weight: .bold))
                                        Text("ARMORY")
                                            .font(.system(size: 10, weight: .black, design: .monospaced))
                                    }
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Theme.warning)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .shadow(color: Theme.warning.opacity(0.35), radius: 5, y: 2)
                                }
                                .buttonStyle(TactileButtonStyle())
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                        }
                        .background(Theme.cardBackground.opacity(0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            character.selectedClass.themeColor.opacity(0.55),
                                            Color.white.opacity(0.08),
                                            Color.clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: character.selectedClass.themeColor.opacity(0.14), radius: 14, y: 6)
                        .dndBorder(color: character.selectedClass.themeColor.opacity(0.55), length: 16, lineWidth: 1.5)
                    }
                    .padding(.horizontal)
                    
                    // Equipped Gear Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("EQUIPPED GEAR")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textSecondary)
                            .tracking(1.2)

                        let equippedRing = character.equippedRing
                        let equippedAmulet = character.equippedAmulet

                        VStack(spacing: 10) {
                            // Armor row
                            ProfileGearRow(
                                icon: equippedArmor?.getIconName() ?? "shield.fill",
                                label: "ARMOR",
                                item: equippedArmor,
                                emptyText: "No Armor Equipped",
                                emptySubtext: "Defense stats minimized",
                                accentColor: equippedArmor?.rarity.color ?? .gray
                            )

                            Divider().background(Theme.border)

                            // Weapon row (read from character computed prop)
                            let equippedWeaponDirect = character.equippedWeapon
                            ProfileGearRow(
                                icon: equippedWeaponDirect?.getIconName() ?? "bolt.slash",
                                label: "WEAPON",
                                item: equippedWeaponDirect,
                                emptyText: "No Weapon Equipped",
                                emptySubtext: "Combat Power not boosted",
                                accentColor: equippedWeaponDirect?.rarity.color ?? .gray
                            )

                            Divider().background(Theme.border)

                            // Ring row
                            ProfileGearRow(
                                icon: equippedRing?.getIconName() ?? "circle.circle.fill",
                                label: "RING",
                                item: equippedRing,
                                emptyText: "No Ring Equipped",
                                emptySubtext: "Visit shop to boost power",
                                accentColor: equippedRing?.rarity.color ?? .gray
                            )

                            Divider().background(Theme.border)

                            // Amulet row
                            ProfileGearRow(
                                icon: equippedAmulet?.getIconName() ?? "diamond.fill",
                                label: "AMULET",
                                item: equippedAmulet,
                                emptyText: "No Amulet Equipped",
                                emptySubtext: "Visit shop to boost power",
                                accentColor: equippedAmulet?.rarity.color ?? .gray
                            )
                        }
                        .padding()
                        .background(Theme.cardBackground.opacity(0.85))
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 0.8))

                        Button(action: { showArmoryShop = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "cart.fill")
                                Text("OPEN ARMORY SHOP")
                            }
                            .font(.system(size: 12, design: .monospaced))
                            .fontWeight(.black)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.warning)
                            .cornerRadius(12)
                            .shadow(color: Theme.warning.opacity(0.4), radius: 6)
                        }
                        .buttonStyle(TactileButtonStyle())

                        Button(action: { showInventory = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "backpack.fill")
                                Text("INVENTORY")
                            }
                            .font(.system(size: 12, design: .monospaced))
                            .fontWeight(.black)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.secondaryCard.opacity(0.9))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Theme.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(TactileButtonStyle())
                        
                        Button(action: { showConstellations = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .glow(color: .white, radius: 4)
                                Text("SKILL CONSTELLATIONS")
                            }
                            .font(.system(size: 12, design: .monospaced))
                            .fontWeight(.black)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "4F46E5"), Color(hex: "06B6D4")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: Color(hex: "4F46E5").opacity(0.4), radius: 6)
                        }
                        .buttonStyle(TactileButtonStyle())
                    }
                    .padding(.horizontal)

                    
                    // 2x2 Class Grid Selector
                    VStack(alignment: .leading, spacing: 12) {
                        Text("HERO CLASS PROGRESSION (2X2 GRID)")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textSecondary)
                            .tracking(1.2)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            ForEach(CharacterClass.allCases) { charClass in
                                let isSelected = character.selectedClass == charClass
                                let prog = character.progressions[charClass.rawValue]
                                let lvl = prog?.level ?? 1
                                let reps = prog?.totalReps ?? 0
                                
                                Button(action: {
                                    guard var char = firebaseService.currentCharacter else { return }
                                    if char.selectedClass != charClass {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            char.selectedClass = charClass
                                            firebaseService.syncCharacter(char)
                                            profileToastMessage = "Class changed to \(charClass.rawValue)!"
                                        }
                                        
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                            if profileToastMessage == "Class changed to \(charClass.rawValue)!" {
                                                withAnimation {
                                                    profileToastMessage = nil
                                                }
                                            }
                                        }
                                    }
                                }) {
                                    VStack(spacing: 8) {
                                        ZStack {
                                            Circle()
                                                .fill(charClass.themeColor.opacity(isSelected ? 0.25 : 0.08))
                                                .frame(width: 44, height: 44)
                                            
                                            Image(systemName: classIcon(for: charClass))
                                                .font(.title3)
                                                .foregroundColor(charClass.themeColor)
                                        }
                                        .glow(color: isSelected ? charClass.themeColor.opacity(0.3) : .clear, radius: 5)
                                        
                                        VStack(spacing: 2) {
                                            Text(charClass.rawValue.uppercased())
                                                .font(.system(.caption, design: .monospaced))
                                                .fontWeight(.black)
                                                .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)
                                            
                                            Text("LVL \(lvl) • \(reps) REPS")
                                                .font(.system(size: 9, design: .monospaced))
                                                .foregroundColor(isSelected ? charClass.themeColor : Theme.textMuted)
                                        }
                                    }
                                    .padding(.vertical, 14)
                                    .frame(maxWidth: .infinity)
                                    .background(isSelected ? Theme.secondaryCard.opacity(0.85) : Theme.cardBackground.opacity(0.6))
                                    .cornerRadius(14)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(isSelected ? charClass.themeColor : Theme.border, lineWidth: isSelected ? 2 : 1)
                                    )
                                    .scaleEffect(isSelected ? 1.02 : 0.98)
                                }
                                .buttonStyle(TactileButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // RPG Stats Panel
                    VStack(alignment: .leading, spacing: 16) {
                        Text("CHARACTER ATTRIBUTES")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textSecondary)
                            .tracking(1)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            AttributeCard(name: "Strength (STR)", value: strength, icon: "flame.fill", color: Theme.swordsmanColor)
                            AttributeCard(name: "Dexterity (DEX)", value: dexterity, icon: "figure.run", color: Theme.archerColor)
                            AttributeCard(name: "Vitality (VIT)", value: vitality, icon: "heart.fill", color: Theme.healerColor)
                            AttributeCard(name: "Intelligence (INT)", value: intelligence, icon: "sparkles", color: Theme.mageColor)
                            AttributeCard(name: "Defense (DEF)", value: defense, icon: "shield.fill", color: Theme.success)
                            AttributeCard(name: "Power (PWR)", value: character.combatPower, icon: "bolt.fill", color: Theme.warning)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Workout history details card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("WORKOUT METRICS")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textSecondary)
                            .tracking(1)
                        
                        VStack(spacing: 12) {
                            RepHistoryRow(name: "Squats (Archer)", count: character.stats.totalSquats, color: Theme.archerColor)
                            RepHistoryRow(name: "Push-ups (Mage)", count: character.stats.totalPushups, color: Theme.mageColor)
                            RepHistoryRow(name: "Pull-ups (Swordsman)", count: character.stats.totalPullups, color: Theme.swordsmanColor)
                            RepHistoryRow(name: "Dips (Healer)", count: character.stats.totalDips, color: Theme.healerColor)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Health Sync Section
                    HealthSyncTabView()
                        .padding(.horizontal)

                    settingsSection
                        .padding(.horizontal)
                    
                    // Achievements
                    VStack(alignment: .leading, spacing: 16) {
                        Text("ACHIEVEMENTS")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textSecondary)
                            .tracking(1)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                AchievementBadge(
                                    title: "First Rep",
                                    desc: "Start journey",
                                    icon: "bolt.fill",
                                    unlocked: character.stats.totalReps >= 1
                                )
                                AchievementBadge(
                                    title: "Squat Adept",
                                    desc: "50 squats",
                                    icon: "figure.walk",
                                    unlocked: character.stats.totalSquats >= 50
                                )
                                AchievementBadge(
                                    title: "Push Master",
                                    desc: "100 pushups",
                                    icon: "crown.fill",
                                    unlocked: character.stats.totalPushups >= 100
                                )
                                AchievementBadge(
                                    title: "Gladiator",
                                    desc: "First PvP win",
                                    icon: "suit.spade.fill",
                                    unlocked: character.unwrappedPvPWins >= 1
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
            
            // Floating Toast notification for profile screen class switches
            if let msg = profileToastMessage {
                VStack {
                    FloatingToastView(message: msg)
                        .padding(.top, 50)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .sheet(isPresented: $showArmoryShop) {
            ArmoryShopView()
        }
        .fullScreenCover(isPresented: $showInventory) {
            InventoryView()
        }
        .sheet(isPresented: $showAvatarSelector) {
            AvatarSelectorView(selectedAvatar: Binding(
                get: { character.avatarName ?? "avatar_knight" },
                set: { newAvatar in
                    var updated = character
                    updated.avatarName = newAvatar
                    firebaseService.syncCharacter(updated)
                }
            ), accentColor: character.selectedClass.themeColor)
        }
        .fullScreenCover(isPresented: $showConstellations) {
            ConstellationSkillTreeView()
        }
        .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Account", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("This permanently deletes your FitRPG character, notifications, and game progress. This cannot be undone.")
        }
        .alert("Couldn't Delete Account", isPresented: $showDeleteAccountError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deleteAccountError ?? "Unknown error")
        }
        .alert("Authentication Error", isPresented: Binding(
            get: { authErrorMessage != nil },
            set: { if !$0 { authErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(authErrorMessage ?? "")
        }
        .alert("Account Deleted", isPresented: $showAccountDeletedConfirmation) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text("Your FitRPG data has been removed.")
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SETTINGS")
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(Theme.textSecondary)
                .tracking(1)

            VStack(spacing: 0) {
                settingsDocumentRow(title: "Privacy Policy", icon: "hand.raised.fill", document: "privacy")
                Divider().background(Theme.border)
                settingsDocumentRow(title: "Terms of Use", icon: "doc.text.fill", document: "terms")
                Divider().background(Theme.border)
                settingsDocumentRow(title: "Support", icon: "questionmark.circle.fill", document: "support")
            }
            .background(Theme.cardBackground.opacity(0.85))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 0.8))
            .sheet(item: $presentedLegalDocument) { doc in
                NavigationStack {
                    LegalDocumentView(documentName: doc.name)
                        .navigationTitle(doc.title)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { presentedLegalDocument = nil }
                            }
                        }
                }
            }

            Text("FitRPG is for entertainment and fitness motivation only. It is not medical advice. Consult a physician before starting any exercise program.")
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(Theme.textMuted)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 4)

            HStack {
                Text(appVersionLabel)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(Theme.textMuted)
                Spacer()
                Link("Open Support in Safari", destination: LegalURLs.publicSupport)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(Theme.accent)
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)

            if showsScreenshotFillButton {
                Button(action: { Task { await fillForScreenshots() } }) {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Fill for Screenshots")
                        Spacer()
                        if isFillingScreenshotWallet { ProgressView() }
                    }
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.accent)
                    .padding()
                    .background(Theme.accent.opacity(0.12))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.accent.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(TactileButtonStyle())
                .disabled(isFillingScreenshotWallet || isProcessingAccountAction)
                .accessibilityLabel("Fill gold and energy for screenshots")
            }

            if authManager.isAnonymous {
                VStack(spacing: 10) {
                    Button(action: { Task { await signInWithApple() } }) {
                        HStack {
                            Image(systemName: "apple.logo")
                            Text("Sign in with Apple")
                            Spacer()
                            if isProcessingAccountAction { ProgressView().tint(.white) }
                        }
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(12)
                    }
                    .buttonStyle(TactileButtonStyle())
                    .disabled(isProcessingAccountAction)

                    Button(action: { Task { await signInWithGoogle() } }) {
                        HStack {
                            Image(systemName: "globe")
                            Text("Continue with Google")
                            Spacer()
                            if isProcessingAccountAction { ProgressView() }
                        }
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textPrimary)
                        .padding()
                        .background(Theme.secondaryCard.opacity(0.85))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(TactileButtonStyle())
                    .disabled(isProcessingAccountAction)

                    Text("Link an account to save progress across devices.")
                        .font(.caption2)
                        .foregroundColor(Theme.textMuted)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if let email = authManager.currentUserEmail ?? authManager.currentUser?.displayName {
                        Text("Signed in as \(email)")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                    Button(action: { Task { await signOut() } }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                            Spacer()
                            if isProcessingAccountAction { ProgressView() }
                        }
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.warning)
                        .padding()
                        .background(Theme.warning.opacity(0.12))
                        .cornerRadius(12)
                    }
                    .buttonStyle(TactileButtonStyle())
                    .disabled(isProcessingAccountAction)
                }
            }

            Button(role: .destructive, action: { showDeleteAccountAlert = true }) {
                HStack {
                    Image(systemName: "person.crop.circle.badge.xmark")
                    Text("Delete Account")
                    Spacer()
                    if isProcessingAccountAction { ProgressView() }
                }
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(Theme.danger)
                .padding()
                .background(Theme.danger.opacity(0.12))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.danger.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(TactileButtonStyle())
            .disabled(isProcessingAccountAction)
        }
    }

    @ViewBuilder
    private func settingsDocumentRow(title: String, icon: String, document: String) -> some View {
        Button {
            presentedLegalDocument = LegalDocumentRef(name: document, title: title)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(Theme.primary)
                    .frame(width: 24)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Theme.textMuted)
            }
            .padding()
        }
        .buttonStyle(.plain)
    }

    private func settingsLinkRow(title: String, icon: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(Theme.primary)
                    .frame(width: 24)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Image(systemName: "arrow.up.forward")
                    .font(.caption)
                    .foregroundColor(Theme.textMuted)
            }
            .padding()
        }
    }

    private var showsScreenshotFillButton: Bool {
        #if DEBUG
        return true
        #else
        return remoteConfig.screenshotFillEnabled
        #endif
    }

    private func fillForScreenshots() async {
        isFillingScreenshotWallet = true
        defer { isFillingScreenshotWallet = false }
        let (ok, err) = await firebaseService.fillScreenshotWallet()
        if ok {
            profileToastMessage = "Wallet filled: 9999 gold, full energy"
        } else {
            profileToastMessage = err ?? "Screenshot fill failed"
        }
    }

    private func signInWithApple() async {
        isProcessingAccountAction = true
        defer { isProcessingAccountAction = false }
        do {
            try await SocialAuthService.shared.signInWithApple()
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    private func signInWithGoogle() async {
        isProcessingAccountAction = true
        defer { isProcessingAccountAction = false }
        do {
            try await SocialAuthService.shared.signInWithGoogle()
        } catch let error as NSError where error.code == GIDSignInError.canceled.rawValue {
            // User cancelled — no alert
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    private func signOut() async {
        isProcessingAccountAction = true
        defer { isProcessingAccountAction = false }
        do {
            try await SocialAuthService.shared.signOut()
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    private func deleteAccount() async {
        guard let uid = authManager.currentUser?.uid else {
            deleteAccountError = "No signed-in user found."
            showDeleteAccountError = true
            return
        }

        isProcessingAccountAction = true
        defer { isProcessingAccountAction = false }

        do {
            try await SocialAuthService.shared.reauthenticateForDeletion()
            try await firebaseService.deleteFitRPGAccountData(uid: uid)
            // Guideline 5.1.1(v): always delete the Auth user (anonymous and linked).
            try await authManager.deleteCurrentUser()
            showAccountDeletedConfirmation = true
        } catch {
            deleteAccountError = error.localizedDescription
            showDeleteAccountError = true
        }
    }
    
    private func classIcon(for cls: CharacterClass) -> String {
        switch cls {
        case .archer: return "arrow.up.forward.app.fill"
        case .mage: return "bolt.heart.fill"
        case .swordsman: return "hammer.fill"
        case .healer: return "cross.case.fill"
        }
    }
    
}

struct AvatarSelectorView: View {
    @Binding var selectedAvatar: String
    let accentColor: Color
    @Environment(\.dismiss) private var dismiss

    private let avatarOptions: [AvatarEmblem] = AvatarEmblem.all

    let columnLayout = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()

            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("SELECT AVATAR")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                        .tracking(2)
                        .padding(.top, 24)

                    Text("CHOOSE YOUR ICON")
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.black)
                        .foregroundColor(Theme.textPrimary)
                }

                ScrollView {
                    LazyVGrid(columns: columnLayout, spacing: 20) {
                        ForEach(avatarOptions) { emblem in
                            let isSelected = selectedAvatar == emblem.id
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedAvatar = emblem.id
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(emblem.tint.opacity(0.22))
                                        .frame(width: 80, height: 80)

                                    if let uiImage = loadLocalAvatar(named: emblem.id) {
                                        Image(platformImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 80, height: 80)
                                            .clipShape(Circle())
                                    } else {
                                        Image(systemName: emblem.symbol)
                                            .font(.system(size: 30, weight: .bold))
                                            .foregroundColor(emblem.tint)
                                    }

                                    // Corner emblem so even grey art reads as distinct
                                    Image(systemName: emblem.symbol)
                                        .font(.system(size: 11, weight: .black))
                                        .foregroundColor(.white)
                                        .padding(5)
                                        .background(emblem.tint)
                                        .clipShape(Circle())
                                        .offset(x: 28, y: 28)
                                }
                                .overlay(
                                    Circle()
                                        .stroke(isSelected ? accentColor : emblem.tint.opacity(0.55), lineWidth: isSelected ? 3 : 1.5)
                                )
                                .glow(color: isSelected ? accentColor.opacity(0.45) : emblem.tint.opacity(0.2), radius: isSelected ? 6 : 3)
                                .scaleEffect(isSelected ? 1.05 : 0.95)
                                .padding(4)
                            }
                            .buttonStyle(TactileButtonStyle())
                            .accessibilityLabel(emblem.label)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }

                Button(action: { dismiss() }) {
                    Text("CONFIRM SELECTION")
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.black)
                        .tracking(1.5)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .glow(color: accentColor.opacity(0.4), radius: 8)
                }
                .buttonStyle(TactileButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

/// Distinct colored emblem per avatar slot — avoids a grid of identical grey placeholders.
struct AvatarEmblem: Identifiable {
    let id: String
    let symbol: String
    let tint: Color
    let label: String

    static let all: [AvatarEmblem] = [
        AvatarEmblem(id: "avatar_knight", symbol: "shield.fill", tint: Theme.swordsmanColor, label: "Knight"),
        AvatarEmblem(id: "avatar_mage", symbol: "wand.and.stars", tint: Theme.mageColor, label: "Mage"),
        AvatarEmblem(id: "avatar_archer", symbol: "arrow.up.forward", tint: Theme.archerColor, label: "Archer"),
        AvatarEmblem(id: "avatar_healer", symbol: "cross.case.fill", tint: Theme.healerColor, label: "Healer"),
        AvatarEmblem(id: "avatar_dragon", symbol: "flame.fill", tint: Color(hex: "F97316"), label: "Dragon"),
        AvatarEmblem(id: "avatar_phoenix", symbol: "flame.circle.fill", tint: Color(hex: "E11D48"), label: "Phoenix"),
        AvatarEmblem(id: "avatar_goblin", symbol: "leaf.fill", tint: Color(hex: "65A30D"), label: "Goblin"),
        AvatarEmblem(id: "avatar_orc", symbol: "hammer.fill", tint: Color(hex: "A16207"), label: "Orc"),
        AvatarEmblem(id: "avatar_dumbbell", symbol: "dumbbell.fill", tint: Theme.primary, label: "Athlete"),
        AvatarEmblem(id: "avatar_shield", symbol: "shield.lefthalf.filled", tint: Theme.success, label: "Guardian"),
        AvatarEmblem(id: "avatar_potion", symbol: "drop.fill", tint: Color(hex: "06B6D4"), label: "Alchemist"),
        AvatarEmblem(id: "avatar_crown", symbol: "crown.fill", tint: Theme.warning, label: "Crown"),
    ]
}

struct AttributeCard: View {
    let name: String
    let value: Int
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
                .frame(width: 42, height: 42)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .glow(color: color.opacity(0.2), radius: 4)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.textSecondary)
                
                Text("\(value)")
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.black)
                    .foregroundColor(Theme.textPrimary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground.opacity(0.7))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
    }
}
 
struct RepHistoryRow: View {
    let name: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 8, height: 8)
            
            Text(name)
                .font(.caption)
                .foregroundColor(Theme.textPrimary)
            
            Spacer()
            
            Text("\(count) Reps")
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(Theme.textSecondary)
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(10)
    }
}
 
struct AchievementBadge: View {
    let title: String
    let desc: String
    let icon: String
    let unlocked: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(unlocked ? Theme.warning.opacity(0.12) : Color.black.opacity(0.2))
                    .frame(width: 54, height: 54)
                    .overlay(
                        Circle()
                            .stroke(
                                unlocked
                                ? LinearGradient(colors: [Theme.warning, Theme.warning.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color.gray.opacity(0.2), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: unlocked ? 2 : 1
                            )
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(unlocked ? Theme.warning : Theme.textMuted)
                    .glow(color: unlocked ? Theme.warning.opacity(0.4) : .clear, radius: 5)
            }
            
            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 10, weight: .black, design: .default))
                    .foregroundColor(unlocked ? Theme.textPrimary : Theme.textMuted)
                    .lineLimit(1)
                
                Text(desc)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(Theme.textMuted)
                    .lineLimit(1)
            }
        }
        .frame(width: 90, height: 110)
        .background(unlocked ? Theme.cardBackground.opacity(0.8) : Theme.cardBackground.opacity(0.4))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(unlocked ? Theme.warning.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .shadow(color: unlocked ? Theme.warning.opacity(0.08) : Color.clear, radius: 6, x: 0, y: 3)
    }
}

// MARK: - Profile Gear Row
struct ProfileGearRow: View {
    let icon: String
    let label: String
    let item: EquipmentItem?
    let emptyText: String
    let emptySubtext: String
    let accentColor: Color

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 50, height: 50)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(accentColor.opacity(0.3), lineWidth: 1.2)
                    )

                ItemIconView(item: item, fallbackIcon: icon)
                    .frame(width: 28, height: 28)
                    .foregroundColor(accentColor)
            }
            .glow(color: accentColor.opacity(0.35), radius: 6)
            
            VStack(alignment: .leading, spacing: 4) {
                if let item = item {
                    HStack(spacing: 6) {
                        Text(item.name)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text(item.rarity.rawValue.uppercased())
                            .font(.system(size: 8, design: .monospaced))
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(item.rarity.color.opacity(0.2))
                            .foregroundColor(item.rarity.color)
                            .cornerRadius(4)
                    }
                    
                    Text("+\(item.defense > 0 ? item.defense : item.combatPowerBonus) STATS • Boosts combat power")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Theme.success)
                } else {
                    Text(emptyText)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textSecondary)
                    
                    Text(emptySubtext)
                        .font(.caption2)
                        .foregroundColor(Theme.textMuted)
                }
            }
            Spacer()
        }
    }
}
