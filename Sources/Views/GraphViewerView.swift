import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Graph Viewer (3-zone Workbench)
//
// Layout per Codex "Especificación visual":
//   • Left   — project tree: browse intent/extracted/*.json under a chosen folder
//   • Center — active graph: nodes grouped by kind, edges shown for selection
//   • Right  — inspector: full props, source anchors, confidence, state badge

@MainActor
final class GraphViewerModel: ObservableObject {
    @Published var folderURL: URL?
    @Published var graphFiles: [URL] = []
    @Published var currentFileURL: URL?
    @Published var graph: Graph?
    @Published var loadError: String?
    @Published var selectedNodeID: String?

    // Filters
    @Published var hiddenKinds: Set<String> = []     // by NodeKind.rawValue
    @Published var hiddenStates: Set<NodeState> = []

    var nodes: [GraphNode] { graph?.nodes ?? [] }
    var edges: [GraphEdge] { graph?.edges ?? [] }

    var visibleNodes: [GraphNode] {
        nodes.filter { !hiddenKinds.contains($0.kind.rawValue) && !hiddenStates.contains($0.state) }
    }

    var nodesByKind: [(NodeKind, [GraphNode])] {
        let groups = Dictionary(grouping: visibleNodes, by: { $0.kind })
        return groups
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { ($0.key, $0.value.sorted { $0.id < $1.id }) }
    }

    var kindCounts: [(NodeKind, Int)] {
        let groups = Dictionary(grouping: nodes, by: { $0.kind })
        return groups
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { ($0.key, $0.value.count) }
    }

    var stateCounts: [(NodeState, Int)] {
        let groups = Dictionary(grouping: nodes, by: { $0.state })
        return NodeState.allCases.map { ($0, groups[$0]?.count ?? 0) }
    }

    var selectedNode: GraphNode? {
        guard let id = selectedNodeID else { return nil }
        return nodes.first { $0.id == id }
    }

    var edgesFromSelected: [GraphEdge] {
        guard let id = selectedNodeID else { return [] }
        return edges.filter { $0.from == id }
    }

    var edgesToSelected: [GraphEdge] {
        guard let id = selectedNodeID else { return [] }
        return edges.filter { $0.to == id }
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
        graphFiles = discoverGraphFiles(under: url)
    }

    func openGraphPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType.json]
        panel.title = "Open semantic graph JSON"
        if panel.runModal() == .OK, let url = panel.url {
            load(fileURL: url)
        }
    }

    func load(fileURL: URL) {
        currentFileURL = fileURL
        switch loadGraph(at: fileURL) {
        case .success(let g):
            graph = g
            loadError = nil
            selectedNodeID = g.nodes.first?.id
        case .failure(let e):
            graph = nil
            loadError = e.localizedDescription
        }
    }

    /// Look for `intent/extracted/*.json` under the chosen folder, then under
    /// any `*-idl/intent/extracted/*.json` (multi-corpus root).
    private func discoverGraphFiles(under root: URL) -> [URL] {
        let fm = FileManager.default
        var found: [URL] = []
        let direct = root.appendingPathComponent("intent/extracted")
        if let items = try? fm.contentsOfDirectory(at: direct, includingPropertiesForKeys: nil) {
            found.append(contentsOf: items.filter { $0.pathExtension == "json" })
        }
        if let children = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey]) {
            for child in children {
                let isDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                guard isDir, child.lastPathComponent.hasSuffix("-idl") else { continue }
                let sub = child.appendingPathComponent("intent/extracted")
                if let items = try? fm.contentsOfDirectory(at: sub, includingPropertiesForKeys: nil) {
                    found.append(contentsOf: items.filter { $0.pathExtension == "json" })
                }
            }
        }
        return found.sorted { $0.path < $1.path }
    }

    /// Auto-locate the team root and load the realworld demo graph.
    func loadRealworldDemoIfAvailable() {
        let candidates = [
            "/Users/carloshm/personal-projects/intentional",
            FileManager.default.currentDirectoryPath,
            FileManager.default.currentDirectoryPath + "/..",
        ]
        for base in candidates {
            let root = URL(fileURLWithPath: base)
            let f = root.appendingPathComponent("realworld-idl/intent/extracted/realworld-graph.json")
            if FileManager.default.fileExists(atPath: f.path) {
                setFolder(root)
                load(fileURL: f)
                return
            }
        }
    }
}

// MARK: - Root view

struct GraphViewerView: View {
    @StateObject private var model = GraphViewerModel()

    var body: some View {
        NavigationSplitView {
            ProjectSidebar(model: model)
                .navigationSplitViewColumnWidth(min: 220, ideal: 280)
        } content: {
            GraphCenter(model: model)
                .navigationSplitViewColumnWidth(min: 320, ideal: 480)
        } detail: {
            InspectorPane(model: model)
                .navigationSplitViewColumnWidth(min: 280, ideal: 360)
        }
        .onAppear {
            if model.graph == nil {
                model.loadRealworldDemoIfAvailable()
            }
        }
    }
}

// MARK: - Left: project tree + filters

private struct ProjectSidebar: View {
    @ObservedObject var model: GraphViewerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Project").font(.headline)
                Spacer()
                Button("Folder…") { model.chooseFolder() }
                    .controlSize(.small)
                Button("Open Graph…") { model.openGraphPanel() }
                    .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            if let url = model.folderURL {
                Text(url.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.horizontal, 12)
            }

            Divider().padding(.vertical, 6)

            List(selection: Binding(
                get: { model.currentFileURL },
                set: { if let u = $0 { model.load(fileURL: u) } }
            )) {
                Section("Graph files") {
                    ForEach(model.graphFiles, id: \.self) { url in
                        Label(url.lastPathComponent, systemImage: "point.3.connected.trianglepath.dotted")
                            .tag(url)
                    }
                    if model.graphFiles.isEmpty {
                        Text("No intent/extracted/*.json yet — pick a folder")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Filter — NodeKind") {
                    ForEach(model.kindCounts, id: \.0.rawValue) { (kind, count) in
                        Toggle(isOn: Binding(
                            get: { !model.hiddenKinds.contains(kind.rawValue) },
                            set: { on in
                                if on { model.hiddenKinds.remove(kind.rawValue) }
                                else { model.hiddenKinds.insert(kind.rawValue) }
                            }
                        )) {
                            HStack {
                                Text(kind.rawValue).font(.system(.body, design: .monospaced))
                                Spacer()
                                Text("\(count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }

                Section("Filter — State") {
                    ForEach(model.stateCounts, id: \.0) { (state, count) in
                        Toggle(isOn: Binding(
                            get: { !model.hiddenStates.contains(state) },
                            set: { on in
                                if on { model.hiddenStates.remove(state) }
                                else { model.hiddenStates.insert(state) }
                            }
                        )) {
                            HStack {
                                StateBadge(state: state)
                                Spacer()
                                Text("\(count)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }
            }
        }
    }
}

// MARK: - Center: nodes-by-kind list

private struct GraphCenter: View {
    @ObservedObject var model: GraphViewerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if let err = model.loadError {
                ScrollView {
                    Text(err)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .padding()
                }
            } else if model.graph == nil {
                ContentUnavailable
            } else {
                List(selection: Binding(
                    get: { model.selectedNodeID },
                    set: { model.selectedNodeID = $0 }
                )) {
                    ForEach(model.nodesByKind, id: \.0.rawValue) { (kind, nodes) in
                        Section("\(kind.rawValue) (\(nodes.count))") {
                            ForEach(nodes) { n in
                                NodeRow(node: n)
                                    .tag(Optional(n.id))
                            }
                        }
                    }

                    if let sel = model.selectedNode {
                        Section("Edges from \(sel.id)") {
                            if model.edgesFromSelected.isEmpty {
                                Text("(none)").font(.caption).foregroundStyle(.secondary)
                            }
                            ForEach(model.edgesFromSelected, id: \.stableID) { e in
                                EdgeRow(edge: e, fromSelected: true)
                            }
                        }
                        Section("Edges to \(sel.id)") {
                            if model.edgesToSelected.isEmpty {
                                Text("(none)").font(.caption).foregroundStyle(.secondary)
                            }
                            ForEach(model.edgesToSelected, id: \.stableID) { e in
                                EdgeRow(edge: e, fromSelected: false)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.currentFileURL?.lastPathComponent ?? "No graph loaded")
                    .font(.headline)
                if let m = model.graph?.metadata {
                    Text([m.project, m.kernel_version, m.wave]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let g = model.graph {
                Text("\(g.nodes.count) nodes · \(g.edges.count) edges")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
    }

    private var ContentUnavailable: some View {
        VStack(spacing: 12) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text("Open a graph JSON to begin")
                .font(.title3)
            Button("Open Graph…") { model.openGraphPanel() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct NodeRow: View {
    let node: GraphNode
    var body: some View {
        HStack(spacing: 8) {
            StateBadge(state: node.state)
            VStack(alignment: .leading, spacing: 1) {
                Text(node.id)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                Text(node.displayLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            if let bc = node.behaviorClassification {
                BehaviorBadge(text: bc)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct EdgeRow: View {
    let edge: GraphEdge
    let fromSelected: Bool
    var body: some View {
        HStack(spacing: 6) {
            Text(edge.kind.rawValue)
                .font(.caption.monospaced())
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(Capsule())
            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(fromSelected ? edge.to : edge.from)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
        }
    }
}

// MARK: - Right: inspector

private struct InspectorPane: View {
    @ObservedObject var model: GraphViewerModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let n = model.selectedNode {
                    inspectorContent(for: n)
                } else {
                    Text("Inspector").font(.headline)
                    Text("Select a node to inspect its properties, source anchors, and confidence.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func inspectorContent(for n: GraphNode) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(n.id).font(.system(.title3, design: .monospaced)).textSelection(.enabled)
            HStack(spacing: 8) {
                Text(n.kind.rawValue)
                    .font(.caption.monospaced())
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Capsule())
                StateBadge(state: n.state)
                if let by = n.created_by {
                    Text("by \(by.rawValue)").font(.caption).foregroundStyle(.secondary)
                }
                if let bc = n.behaviorClassification {
                    BehaviorBadge(text: bc)
                }
            }
        }

        if let conf = n.confidence {
            GroupBox("Confidence") {
                VStack(alignment: .leading, spacing: 2) {
                    if let s = conf.score {
                        Text(String(format: "score %.2f", s)).font(.callout.monospacedDigit())
                    }
                    if let m = conf.model { Text("model: \(m)").font(.caption) }
                    if let r = conf.run_id { Text("run: \(r)").font(.caption) }
                    if let r = conf.rationale {
                        Text(r).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        if let anchors = n.source_anchors, !anchors.isEmpty {
            GroupBox("Source Anchors") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(anchors) { a in
                        AnchorRow(anchor: a)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        if let props = n.props, !props.isEmpty {
            GroupBox("Props") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(props.sorted(by: { $0.key < $1.key }), id: \.key) { k, v in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(k).font(.caption.bold())
                            Text(v.displayString)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct AnchorRow: View {
    let anchor: SourceAnchor
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: iconName)
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Button(action: open) {
                    Text(anchor.uri)
                        .font(.system(.caption, design: .monospaced))
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
                if let r = anchor.range, let s = r.start_line, let e = r.end_line {
                    Text("lines \(s)–\(e)").font(.caption2).foregroundStyle(.secondary)
                }
                if let h = anchor.hash {
                    Text(h).font(.caption2.monospaced()).foregroundStyle(.tertiary).lineLimit(1)
                }
            }
        }
    }

    private var iconName: String {
        if anchor.uri.hasPrefix("file://") || anchor.uri.hasPrefix("/") { return "doc.text" }
        if anchor.uri.hasPrefix("repo://") { return "folder" }
        return "link"
    }

    private func open() {
        let pb = NSPasteboard.general
        if let url = fileURL(for: anchor.uri), FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.open(url)
            return
        }
        // Fallback: copy to clipboard.
        pb.clearContents()
        pb.setString(anchor.uri, forType: .string)
    }

    private func fileURL(for uri: String) -> URL? {
        if uri.hasPrefix("file://") { return URL(string: uri) }
        if uri.hasPrefix("/") { return URL(fileURLWithPath: uri) }
        return nil
    }
}

// MARK: - Badges

private struct StateBadge: View {
    let state: NodeState
    var body: some View {
        Text(state.rawValue)
            .font(.caption2.bold())
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
    private var color: Color {
        switch state {
        case .accepted: return .green
        case .proposed: return .blue
        case .inferred: return .teal
        case .questioned: return .orange
        case .rejected: return .red
        case .drifted: return .purple
        }
    }
}

private struct BehaviorBadge: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color.gray.opacity(0.18))
            .clipShape(Capsule())
    }
}
