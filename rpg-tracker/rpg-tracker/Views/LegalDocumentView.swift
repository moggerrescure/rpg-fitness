import SwiftUI
import WebKit

struct LegalDocumentRef: Identifiable {
    let id = UUID()
    let name: String
    let title: String
}

struct LegalDocumentView: View {
    let documentName: String

    var body: some View {
        Group {
            if let url = Bundle.main.url(forResource: documentName, withExtension: "html", subdirectory: "Legal")
                ?? Bundle.main.url(forResource: documentName, withExtension: "html") {
                LegalWebView(url: url)
            } else {
                ContentUnavailableView(
                    "Document unavailable",
                    systemImage: "doc.text",
                    description: Text("Add \(documentName).html under Legal/ in the app bundle.")
                )
            }
        }
    }
}

private struct LegalWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
