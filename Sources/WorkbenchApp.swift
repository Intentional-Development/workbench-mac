import SwiftUI

@main
struct WorkbenchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            EditorView()
                .tabItem {
                    Label("Editor", systemImage: "doc.text")
                }
                .tag(0)
            
            ExtractView()
                .tabItem {
                    Label("Extract", systemImage: "arrow.down.doc")
                }
                .tag(1)
            
            EmitView()
                .tabItem {
                    Label("Emit", systemImage: "arrow.up.doc")
                }
                .tag(2)
            
            DriftView()
                .tabItem {
                    Label("Drift", systemImage: "chart.bar.xaxis")
                }
                .tag(3)
        }
        .padding()
    }
}
