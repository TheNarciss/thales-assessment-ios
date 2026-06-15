import SwiftUI
import CryptoKit

struct ContentView: View {
    @State private var keypair: P256.Signing.PrivateKey?

    var body: some View {
        TabView {
            HashView()
                .tabItem {
                    Label("Hash", systemImage: "number.square.fill")
                }

            KeysView(keypair: $keypair)
                .tabItem {
                    Label("Keys", systemImage: "key.fill")
                }

            SignVerifyView(keypair: keypair)
                .tabItem {
                    Label("Sign", systemImage: "signature")
                }
        }
        .tint(.indigo)
    }
}

#Preview {
    ContentView()
}
