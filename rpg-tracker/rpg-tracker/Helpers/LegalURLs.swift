import Foundation
import SwiftUI

enum LegalURLs {
    /// Bundled copies for reliable in-app viewing (also required for App Store Connect as a public HTTPS URL — publish `fitrpg-legal/`).
    static var privacyPolicy: URL { bundled("privacy") ?? remote("privacy") }
    static var termsOfUse: URL { bundled("terms") ?? remote("terms") }
    static var support: URL { bundled("support") ?? remote("support") }

    /// Public URL for App Store Connect (update after GitHub Pages / custom domain is live).
    static let publicPrivacyPolicy = URL(string: "https://borisserz.github.io/fitrpg-legal/privacy.html")!
    static let publicTermsOfUse = URL(string: "https://borisserz.github.io/fitrpg-legal/terms.html")!
    static let publicSupport = URL(string: "https://borisserz.github.io/fitrpg-legal/support.html")!

    private static func bundled(_ name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "html", subdirectory: "Legal")
            ?? Bundle.main.url(forResource: name, withExtension: "html")
    }

    private static func remote(_ name: String) -> URL {
        URL(string: "https://borisserz.github.io/fitrpg-legal/\(name).html")!
    }
}
