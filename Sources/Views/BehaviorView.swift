import SwiftUI
import AppKit

// MARK: - Behavior Classification Viewer (W23)
//
// Displays nodes grouped by confidence.metadata.behavior (schema v0.1.9).
// Shows distribution stats (count + % per role) and color-coded legend.

@MainActor
final class BehaviorViewModel: ObservableObject {
    @Published var folderURL: URL?
    @Published var graphFiles: [URL] = []
    @Published var currentFileURL: URL?
    @Published var graph: Graph?
    @Published var loadError: String?
    @Published var selectedRole: BehaviorRole?
    
    var distribution: [BehaviorDistribution] {
        graph?.behaviorDistribution ?? []
    }
    
    var unclassifiedCount: Int {
        graph?.unclassifiedNodeCount ?? 0
    }
    
    var totalNodesWithBehavior: Int {
        distribution.reduce(0) { $0 + $1.count }
    }
    
    var selectedNodes: [GraphNode] {
        guard let role = selectedRole else { return [] }
        return distribution.first { $0.role == role }?.nodes ?? []
    }
    
    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Choose corpus root (containing intent/extracted/*.json)"
        if panel.runModal() == .OK, let url = panel.url {
            setFolder(url)
        }
    }
    
    func setFolder(_ url: URL) {
        folderURL = url
        scanGraphFiles()
        if let first = graphFiles.first {
            loadGraph(first)
        }
    }
    
    func scanGraphFiles() {
        guard let folder = folderURL else {
            graphFiles = []
            return
        }
        
        let fm = FileManager.default
        var found: [URL] = []
        
        // Look in intent/extracted/*.json
        let intentExtracted = folder.appendingPathComponent("intent/extracted", isDirectory: true)
        if fm.fileExists(atPath: intentExtracted.path) {
            if let enumerator = fm.enumerator(at: intentExtracted, includingPropertiesForKeys: nil) {
                for case let fileURL as URL in enumerator {
                    if fileURL.pathExtension == "json" {
                        found.append(fileURL)
                    }
                }
            }
        }
        
        graphFiles = found.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
    
    func loadGraph(_ url: URL) {
        currentFileURL = url
        loadError = nil
        graph = nil
        selectedRole = nil
        
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(Graph.self, from: data)
            graph = decoded
        } catch {
            loadError = "Failed to load graph: \(error.localizedDescription)"
        }
    }
}

struct BehaviorView: View {
    @StateObject private var model = BehaviorViewModel()
    
    var body: some View {
        HSplitView {
            // Left: File picker + stats summary
            VStack(alignment: .leading, spacing: 16) {
                if model.folderURL == nil {
                    Button("Choose Folder") {
                        model.chooseFolder()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Corpus: \(model.folderURL?.lastPathComponent ?? "")")
                            .font(.headline)
                        
                        if !model.graphFiles.isEmpty {
                            Text("\(model.graphFiles.count) graph files")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Button("Change Folder") {
                            model.chooseFolder()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    
                    Divider()
                    
                    // File list
                    List(model.graphFiles, id: \.self, selection: Binding(
                        get: { model.currentFileURL },
                        set: { if let url = $0 { model.loadGraph(url) } }
                    )) { url in
                        Text(url.lastPathComponent)
                            .font(.system(.body, design: .monospaced))
                    }
                    .frame(minWidth: 200)
                }
            }
            .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)
            
            // Center: Distribution stats + role groups
            VStack(alignment: .leading, spacing: 0) {
                if let error = model.loadError {
                    Text("Error: \(error)")
                        .foregroundStyle(.red)
                        .padding()
                } else if let graph = model.graph {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Behavior Classification")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        HStack(spacing: 24) {
                            VStack(alignment: .leading) {
                                Text("Total Nodes")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(graph.nodes.count)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Classified")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(model.totalNodesWithBehavior)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.green)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Unclassified")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(model.unclassifiedCount)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .padding()
                    
                    Divider()
                    
                    // Distribution chart
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(model.distribution) { dist in
                                BehaviorRoleRow(
                                    distribution: dist,
                                    isSelected: model.selectedRole == dist.role,
                                    onTap: { model.selectedRole = dist.role }
                                )
                            }
                            
                            if model.unclassifiedCount > 0 {
                                HStack {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 12, height: 12)
                                    Text("Unclassified")
                                        .font(.system(.body, design: .monospaced))
                                    Spacer()
                                    Text("\(model.unclassifiedCount)")
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }
                        }
                        .padding()
                    }
                } else {
                    Text("Select a graph file to view behavior distribution")
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .frame(minWidth: 300, idealWidth: 400)
            
            // Right: Inspector (selected role's nodes)
            VStack(alignment: .leading, spacing: 0) {
                if let role = model.selectedRole {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Circle()
                                .fill(colorForRole(role))
                                .frame(width: 16, height: 16)
                            Text(role.description)
                                .font(.headline)
                        }
                        
                        Text("\(model.selectedNodes.count) nodes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    
                    Divider()
                    
                    List(model.selectedNodes, id: \.id) { node in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(node.name)
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.medium)
                            
                            Text(node.kind.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            if let conf = node.confidence, let score = conf.score {
                                Text(String(format: "Confidence: %.0f%%", score * 100))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    Text("Select a behavior role to view nodes")
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .frame(minWidth: 250, idealWidth: 300)
        }
    }
    
    private func colorForRole(_ role: BehaviorRole) -> Color {
        switch role {
        case .entity: return .blue
        case .valueObject: return .green
        case .command: return .orange
        case .event: return .red
        case .queryResult: return .purple
        case .dtoOnly: return .gray
        }
    }
}

struct BehaviorRoleRow: View {
    let distribution: BehaviorDistribution
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Circle()
                    .fill(colorForRole(distribution.role))
                    .frame(width: 12, height: 12)
                
                Text(distribution.role.description)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("\(distribution.count)")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
                
                Text(String(format: "%.1f%%", distribution.percentage))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
    
    private func colorForRole(_ role: BehaviorRole) -> Color {
        switch role {
        case .entity: return .blue
        case .valueObject: return .green
        case .command: return .orange
        case .event: return .red
        case .queryResult: return .purple
        case .dtoOnly: return .gray
        }
    }
}
