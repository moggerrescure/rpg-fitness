import SwiftUI
struct TestView: View {
    var body: some View {
        ZStack {
            Text("Hi")
        }
        .sheet(isPresented: .constant(false)) { Text("A") }
        .fullScreenCover(isPresented: .constant(false)) { Text("B") }
        .sheet(isPresented: .constant(false)) { Text("C") }
    }
}
