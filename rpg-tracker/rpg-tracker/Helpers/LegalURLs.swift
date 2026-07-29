import Foundation

enum LegalURLs {
    // Served from main via jsDelivr until dedicated GitHub Pages hosting is configured.
    // Prefer publishing `fitrpg-legal/` to https://borisserz.github.io/fitrpg-legal/ for App Store.
    static let privacyPolicy = URL(string: "https://cdn.jsdelivr.net/gh/moggerrescure/rpg-fitness@main/fitrpg-legal/privacy.html")!
    static let termsOfUse = URL(string: "https://cdn.jsdelivr.net/gh/moggerrescure/rpg-fitness@main/fitrpg-legal/terms.html")!
    static let support = URL(string: "https://cdn.jsdelivr.net/gh/moggerrescure/rpg-fitness@main/fitrpg-legal/support.html")!
}
