import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "hammer.circle")
                .font(.system(size: 56))
            Text("Project initialized")
                .font(.title2.weight(.semibold))
            Text("Replace ContentView with the app's real screens.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
