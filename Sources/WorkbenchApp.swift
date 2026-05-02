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

            GraphViewerView()
                .tabItem {
                    Label("Graph", systemImage: "point.3.connected.trianglepath.dotted")
                }
                .tag(4)

            DriftDashboardView()
                .tabItem {
                    Label("Drift Dashboard", systemImage: "waveform.badge.magnifyingglass")
                }
                .tag(5)
            
            BehaviorView()
                .tabItem {
                    Label("Behavior", systemImage: "list.bullet.rectangle")
                }
                .tag(6)
            
            DerivedPromptsView()
                .tabItem {
                    Label("Prompts", systemImage: "text.bubble")
                }
                .tag(7)
            
            ProposalReviewView()
                .tabItem {
                    Label("Proposals", systemImage: "doc.on.doc")
                }
                .tag(8)
        }
        .padding()
    }
}
