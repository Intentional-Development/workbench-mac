import SwiftUI
import AppKit

// MARK: - Graph Canvas View (Wave 9)
//
// SwiftUI Canvas-based renderer for the semantic graph.
//   • Force-directed (Fruchterman-Reingold) layout, cached in `LayoutStore`.
//   • Visual encoding: shape per NodeKind, fill per NodeState, edge style per EdgeKind.
//   • Click → select; drag node → manual override; Cmd+scroll → zoom; drag empty → pan;
//     double-click → focus mode (dim non-neighbors).
//   • Designed for 300+ nodes — uses a single Canvas, not one SwiftUI view per node.

// MARK: - Layout store (cached positions, owned by the viewer model)

@MainActor
final class GraphLayoutStore: ObservableObject {
    @Published private(set) var positions: [String: CGPoint] = [:]
    @Published var manualOverrides: Set<String> = []
    @Published var focusedNodeID: String?
    @Published private(set) var lastSignature: String = ""
    @Published var laidOutSize: CGSize = CGSize(width: 1200, height: 800)

    /// Compute (or reuse) positions for the current graph. Cheap when signature matches.
    func ensureLayout(for graph: Graph?, size: CGSize) {
        guard let graph else {
            positions = [:]; manualOverrides = []; lastSignature = ""; return
        }
        let sig = signature(for: graph)
        let sizeChanged = abs(size.width - laidOutSize.width) > 1 || abs(size.height - laidOutSize.height) > 1
        let needsLayout = sig != lastSignature || (positions.isEmpty && !graph.nodes.isEmpty)
        if needsLayout {
            positions = ForceDirectedLayout.compute(graph: graph, size: size, iterations: graph.nodes.count > 250 ? 120 : 180)
            manualOverrides = []
            focusedNodeID = nil
            lastSignature = sig
            laidOutSize = size
        } else if sizeChanged && !positions.isEmpty {
            // Rescale to new container size while preserving relative layout.
            let scaleX = size.width / max(laidOutSize.width, 1)
            let scaleY = size.height / max(laidOutSize.height, 1)
            for (k, p) in positions {
                positions[k] = CGPoint(x: p.x * scaleX, y: p.y * scaleY)
            }
            laidOutSize = size
        }
    }

    func setPosition(_ id: String, _ p: CGPoint) {
        positions[id] = p
    }

    func markOverride(_ id: String) {
        manualOverrides.insert(id)
    }

    func reset() {
        positions = [:]; manualOverrides = []; focusedNodeID = nil; lastSignature = ""
    }

    private func signature(for g: Graph) -> String {
        // Cheap hash: counts + first/last node ids + edge count.
        let firstID = g.nodes.first?.id ?? ""
        let lastID = g.nodes.last?.id ?? ""
        return "\(g.nodes.count)|\(g.edges.count)|\(firstID)|\(lastID)"
    }
}

// MARK: - Force-directed layout (Fruchterman-Reingold)

enum ForceDirectedLayout {
    static func compute(graph: Graph, size: CGSize, iterations: Int = 150) -> [String: CGPoint] {
        let nodes = graph.nodes
        let n = nodes.count
        guard n > 0 else { return [:] }

        let W = max(size.width, 400)
        let H = max(size.height, 300)
        let area = W * H
        let k = sqrt(area / Double(max(n, 1))) * 0.85
        let kSq = k * k

        // Index nodes
        var idx: [String: Int] = [:]
        idx.reserveCapacity(n)
        for (i, node) in nodes.enumerated() { idx[node.id] = i }

        // Seed positions in a deterministic spiral so the layout is stable run-to-run.
        var px = [Double](repeating: 0, count: n)
        var py = [Double](repeating: 0, count: n)
        let cx = W / 2, cy = H / 2
        for i in 0..<n {
            let t = Double(i)
            let r = 6 + 4 * sqrt(t)
            let a = t * 0.5
            px[i] = cx + r * cos(a)
            py[i] = cy + r * sin(a)
        }

        // Adjacency for attractive forces
        var edgesIdx: [(Int, Int)] = []
        edgesIdx.reserveCapacity(graph.edges.count)
        for e in graph.edges {
            if let a = idx[e.from], let b = idx[e.to], a != b {
                edgesIdx.append((a, b))
            }
        }

        var dx = [Double](repeating: 0, count: n)
        var dy = [Double](repeating: 0, count: n)

        var temp = W / 8.0
        let cool = temp / Double(iterations + 1)

        for _ in 0..<iterations {
            // Reset deltas
            for i in 0..<n { dx[i] = 0; dy[i] = 0 }

            // Repulsive forces — O(n²)
            for i in 0..<n {
                let xi = px[i], yi = py[i]
                for j in (i + 1)..<n {
                    var ddx = xi - px[j]
                    var ddy = yi - py[j]
                    var dist = sqrt(ddx * ddx + ddy * ddy)
                    if dist < 0.01 {
                        ddx = Double.random(in: -0.5...0.5)
                        ddy = Double.random(in: -0.5...0.5)
                        dist = 0.01
                    }
                    let f = kSq / dist
                    let fx = (ddx / dist) * f
                    let fy = (ddy / dist) * f
                    dx[i] += fx; dy[i] += fy
                    dx[j] -= fx; dy[j] -= fy
                }
            }

            // Attractive forces along edges
            for (a, b) in edgesIdx {
                let ddx = px[a] - px[b]
                let ddy = py[a] - py[b]
                let dist = max(sqrt(ddx * ddx + ddy * ddy), 0.01)
                let f = (dist * dist) / k
                let fx = (ddx / dist) * f
                let fy = (ddy / dist) * f
                dx[a] -= fx; dy[a] -= fy
                dx[b] += fx; dy[b] += fy
            }

            // Apply with temperature cap
            for i in 0..<n {
                let disp = sqrt(dx[i] * dx[i] + dy[i] * dy[i])
                if disp > 0.001 {
                    let limited = min(disp, temp)
                    px[i] += (dx[i] / disp) * limited
                    py[i] += (dy[i] / disp) * limited
                }
                // Keep within frame, with a margin
                px[i] = min(max(px[i], 30), W - 30)
                py[i] = min(max(py[i], 30), H - 30)
            }
            temp = max(temp - cool, 0.5)
        }

        var out: [String: CGPoint] = [:]
        out.reserveCapacity(n)
        for i in 0..<n {
            out[nodes[i].id] = CGPoint(x: px[i], y: py[i])
        }
        return out
    }
}

// MARK: - Visual encoding helpers

enum NodeShapeKind {
    case rectangle, diamond, hexagon, triangle, shield, doubleCircle, circle
}

extension NodeKind {
    var shape: NodeShapeKind {
        switch self {
        case .entity, .aggregate: return .rectangle
        case .operation, .accessPattern, .mapping: return .diamond
        case .api: return .hexagon
        case .event: return .triangle
        case .policy, .rule, .invariant, .constraints: return .shield
        case .stateMachine: return .doubleCircle
        default: return .circle
        }
    }
}

extension NodeState {
    var canvasColor: Color {
        switch self {
        case .accepted: return Color.green
        case .proposed: return Color.yellow
        case .inferred: return Color(red: 0.55, green: 0.78, blue: 0.95) // light blue
        case .drifted: return Color.orange
        case .questioned: return Color.purple
        case .rejected: return Color.red
        }
    }
}

enum EdgeStrokeStyle {
    case solid, dashed, dotted, dotMarker

    var dash: [CGFloat] {
        switch self {
        case .solid: return []
        case .dashed: return [6, 4]
        case .dotted: return [2, 4]
        case .dotMarker: return []
        }
    }
}

extension EdgeKind {
    var stroke: EdgeStrokeStyle {
        switch self {
        case .realizes, .implements, .contains, .belongsTo, .variantOf:
            return .solid
        case .tracesTo, .extractedFrom, .supersedes, .derivesFrom:
            return .dashed
        case .constrains, .verifies, .authorizes:
            return .dotted
        case .triggers, .emits, .handles, .transitions, .queries, .decides:
            return .dotMarker
        case .unknown:
            return .dashed
        }
    }

    var lineColor: Color {
        switch self {
        case .realizes, .implements: return Color.gray.opacity(0.85)
        case .triggers, .emits, .handles, .transitions: return Color.blue.opacity(0.7)
        case .constrains, .verifies, .authorizes: return Color.red.opacity(0.6)
        case .tracesTo, .extractedFrom, .derivesFrom, .supersedes: return Color.purple.opacity(0.6)
        case .contains, .belongsTo, .variantOf: return Color.gray.opacity(0.7)
        case .queries, .decides: return Color.teal.opacity(0.8)
        case .unknown: return Color.gray.opacity(0.4)
        }
    }
}

// MARK: - Node geometry

private struct NodeBox {
    let id: String
    let center: CGPoint
    let radius: CGFloat   // bounding-circle radius for hit-testing
}

// MARK: - The Canvas view

struct GraphCanvasView: View {
    @ObservedObject var model: GraphViewerModel
    @StateObject private var layout = GraphLayoutStore()

    // Viewport
    @State private var zoom: CGFloat = 1.0
    @State private var pan: CGSize = .zero

    // Drag state
    @State private var draggingNodeID: String?
    @State private var dragStartPos: CGPoint = .zero
    @State private var panStart: CGSize = .zero
    @State private var isPanning: Bool = false
    @State private var hoverNodeID: String?

    private let nodeRadius: CGFloat = 18

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack(alignment: .topTrailing) {
                Color(NSColor.windowBackgroundColor)

                Canvas { ctx, _ in
                    ctx.translateBy(x: pan.width, y: pan.height)
                    ctx.scaleBy(x: zoom, y: zoom)
                    drawGraph(into: &ctx)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in handleDragChanged(v, size: size) }
                        .onEnded { _ in handleDragEnded() }
                )
                .onTapGesture(count: 2) { loc in
                    if let id = hitTest(at: loc, size: size) {
                        if layout.focusedNodeID == id {
                            layout.focusedNodeID = nil
                        } else {
                            layout.focusedNodeID = id
                            model.selectedNodeID = id
                        }
                    } else {
                        layout.focusedNodeID = nil
                    }
                }
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let p):
                        hoverNodeID = hitTest(at: p, size: size)
                    case .ended:
                        hoverNodeID = nil
                    }
                }
                .background(
                    ScrollWheelCatcher { event in
                        if event.modifierFlags.contains(.command) {
                            let factor: CGFloat = 1.0 + CGFloat(event.scrollingDeltaY) * 0.01
                            let newZoom = max(0.2, min(4.0, zoom * factor))
                            zoom = newZoom
                        } else {
                            pan.width += CGFloat(event.scrollingDeltaX)
                            pan.height += CGFloat(event.scrollingDeltaY)
                        }
                    }
                )

                // Zoom HUD
                HStack(spacing: 6) {
                    Button { zoom = max(0.2, zoom - 0.15) } label: { Image(systemName: "minus.magnifyingglass") }
                    Text("\(Int(zoom * 100))%").font(.caption.monospacedDigit()).frame(width: 44)
                    Button { zoom = min(4.0, zoom + 0.15) } label: { Image(systemName: "plus.magnifyingglass") }
                    Button("Reset") { zoom = 1.0; pan = .zero }
                        .controlSize(.small)
                    Button("Re-layout") {
                        layout.reset()
                        layout.ensureLayout(for: model.graph, size: size)
                    }
                    .controlSize(.small)
                }
                .padding(8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(8)
            }
            .onAppear { layout.ensureLayout(for: model.graph, size: size) }
            .onChange(of: model.graph?.nodes.count ?? 0) { _, _ in
                layout.reset()
                layout.ensureLayout(for: model.graph, size: size)
            }
            .onChange(of: model.currentFileURL) { _, _ in
                layout.reset()
                layout.ensureLayout(for: model.graph, size: size)
            }
        }
    }

    // MARK: - Drawing

    private func drawGraph(into ctx: inout GraphicsContext) {
        guard let graph = model.graph else { return }

        // Build set of focus neighbours if focus mode is active.
        var focusSet: Set<String>? = nil
        if let fid = layout.focusedNodeID {
            var s: Set<String> = [fid]
            for e in graph.edges {
                if e.from == fid { s.insert(e.to) }
                if e.to == fid { s.insert(e.from) }
            }
            focusSet = s
        }

        let visibleIDs = Set(model.visibleNodes.map { $0.id })
        let positions = layout.positions

        // Edges first
        for edge in graph.edges {
            guard visibleIDs.contains(edge.from), visibleIDs.contains(edge.to) else { continue }
            guard let p1 = positions[edge.from], let p2 = positions[edge.to] else { continue }
            let dim: Double = {
                if let fs = focusSet, !(fs.contains(edge.from) && fs.contains(edge.to)) { return 0.15 }
                return 1.0
            }()
            drawEdge(ctx: &ctx, from: p1, to: p2, kind: edge.kind, dim: dim)
        }

        // Nodes
        for node in graph.nodes {
            guard visibleIDs.contains(node.id) else { continue }
            guard let p = positions[node.id] else { continue }
            let dim: Double = {
                if let fs = focusSet, !fs.contains(node.id) { return 0.18 }
                return 1.0
            }()
            drawNode(ctx: &ctx, node: node, at: p, dim: dim,
                     selected: node.id == model.selectedNodeID,
                     hovered: node.id == hoverNodeID)
        }
    }

    private func drawEdge(ctx: inout GraphicsContext, from: CGPoint, to: CGPoint, kind: EdgeKind, dim: Double) {
        let style = kind.stroke
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)

        let color = kind.lineColor.opacity(dim)
        let strokeStyle = StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: style.dash)
        ctx.stroke(path, with: .color(color), style: strokeStyle)

        // Arrowhead
        let dx = to.x - from.x
        let dy = to.y - from.y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 1 else { return }
        let ux = dx / len, uy = dy / len
        // Pull tip back so it doesn't overlap the node center
        let tip = CGPoint(x: to.x - ux * 18, y: to.y - uy * 18)
        let ahLen: CGFloat = 8
        let ahWid: CGFloat = 4
        let leftX = tip.x - ux * ahLen + (-uy) * ahWid
        let leftY = tip.y - uy * ahLen + ( ux) * ahWid
        let rightX = tip.x - ux * ahLen - (-uy) * ahWid
        let rightY = tip.y - uy * ahLen - ( ux) * ahWid
        var arrow = Path()
        arrow.move(to: tip)
        arrow.addLine(to: CGPoint(x: leftX, y: leftY))
        arrow.addLine(to: CGPoint(x: rightX, y: rightY))
        arrow.closeSubpath()
        ctx.fill(arrow, with: .color(color))

        // Dot marker midway for dotMarker style
        if style == .dotMarker {
            let mid = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
            let dot = Path(ellipseIn: CGRect(x: mid.x - 2.5, y: mid.y - 2.5, width: 5, height: 5))
            ctx.fill(dot, with: .color(color))
        }
    }

    private func drawNode(ctx: inout GraphicsContext, node: GraphNode, at p: CGPoint, dim: Double, selected: Bool, hovered: Bool) {
        let r = nodeRadius
        let fill = node.state.canvasColor.opacity(0.85 * dim)
        let stroke = (selected ? Color.accentColor : Color.black.opacity(0.55)).opacity(dim)
        let lineWidth: CGFloat = selected ? 2.5 : (hovered ? 1.8 : 1.0)

        let path = nodePath(kind: node.kind, center: p, radius: r)
        ctx.fill(path, with: .color(fill))
        ctx.stroke(path, with: .color(stroke), lineWidth: lineWidth)

        // Double-circle for state_machine
        if node.kind.shape == .doubleCircle {
            let inner = Path(ellipseIn: CGRect(x: p.x - r * 0.62, y: p.y - r * 0.62,
                                               width: r * 1.24, height: r * 1.24))
            ctx.stroke(inner, with: .color(stroke), lineWidth: 1.0)
        }

        // Confidence badge for AI-proposed nodes
        if node.created_by == .ai, let score = node.confidence?.score {
            let text = String(format: "%.2f", score)
            let badge = Text(text).font(.system(size: 9, weight: .semibold).monospacedDigit())
            ctx.draw(badge, at: CGPoint(x: p.x + r + 2, y: p.y - r + 2), anchor: .topLeading)
        }

        // Label below the node
        let label = Text(node.displayLabel.prefix(28)).font(.system(size: 9))
            .foregroundColor(Color.primary.opacity(dim))
        ctx.draw(label, at: CGPoint(x: p.x, y: p.y + r + 8), anchor: .top)
    }

    private func nodePath(kind: NodeKind, center p: CGPoint, radius r: CGFloat) -> Path {
        switch kind.shape {
        case .rectangle:
            return Path(roundedRect: CGRect(x: p.x - r, y: p.y - r * 0.7,
                                            width: r * 2, height: r * 1.4),
                        cornerRadius: 3)
        case .diamond:
            var pa = Path()
            pa.move(to: CGPoint(x: p.x, y: p.y - r))
            pa.addLine(to: CGPoint(x: p.x + r, y: p.y))
            pa.addLine(to: CGPoint(x: p.x, y: p.y + r))
            pa.addLine(to: CGPoint(x: p.x - r, y: p.y))
            pa.closeSubpath()
            return pa
        case .hexagon:
            var pa = Path()
            for i in 0..<6 {
                let a = (Double(i) / 6.0) * 2 * .pi
                let pt = CGPoint(x: p.x + r * cos(a), y: p.y + r * sin(a))
                if i == 0 { pa.move(to: pt) } else { pa.addLine(to: pt) }
            }
            pa.closeSubpath()
            return pa
        case .triangle:
            var pa = Path()
            pa.move(to: CGPoint(x: p.x, y: p.y - r))
            pa.addLine(to: CGPoint(x: p.x + r, y: p.y + r * 0.8))
            pa.addLine(to: CGPoint(x: p.x - r, y: p.y + r * 0.8))
            pa.closeSubpath()
            return pa
        case .shield:
            // Rounded shield: rect with curved bottom.
            var pa = Path()
            let top = p.y - r * 0.8
            let bot = p.y + r * 0.95
            let left = p.x - r * 0.85
            let right = p.x + r * 0.85
            pa.move(to: CGPoint(x: left, y: top))
            pa.addLine(to: CGPoint(x: right, y: top))
            pa.addLine(to: CGPoint(x: right, y: p.y + r * 0.2))
            pa.addQuadCurve(to: CGPoint(x: left, y: p.y + r * 0.2),
                            control: CGPoint(x: p.x, y: bot))
            pa.closeSubpath()
            return pa
        case .doubleCircle, .circle:
            return Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
        }
    }

    // MARK: - Hit testing & gestures

    private func screenToWorld(_ p: CGPoint) -> CGPoint {
        CGPoint(x: (p.x - pan.width) / zoom, y: (p.y - pan.height) / zoom)
    }

    private func hitTest(at screen: CGPoint, size: CGSize) -> String? {
        let world = screenToWorld(screen)
        let r2 = nodeRadius * nodeRadius * 1.4
        var best: (String, CGFloat)? = nil
        let visible = Set(model.visibleNodes.map { $0.id })
        for (id, p) in layout.positions where visible.contains(id) {
            let dx = p.x - world.x
            let dy = p.y - world.y
            let d2 = dx * dx + dy * dy
            if d2 <= r2 && (best == nil || d2 < best!.1) {
                best = (id, d2)
            }
        }
        return best?.0
    }

    private func handleDragChanged(_ v: DragGesture.Value, size: CGSize) {
        if draggingNodeID == nil && !isPanning {
            // Start: decide between node-drag or pan
            if let id = hitTest(at: v.startLocation, size: size) {
                draggingNodeID = id
                dragStartPos = layout.positions[id] ?? .zero
                model.selectedNodeID = id
            } else {
                isPanning = true
                panStart = pan
            }
        }
        if let id = draggingNodeID {
            let dx = v.translation.width / zoom
            let dy = v.translation.height / zoom
            let np = CGPoint(x: dragStartPos.x + dx, y: dragStartPos.y + dy)
            layout.setPosition(id, np)
            layout.markOverride(id)
        } else if isPanning {
            pan = CGSize(width: panStart.width + v.translation.width,
                         height: panStart.height + v.translation.height)
        }
    }

    private func handleDragEnded() {
        // If it was a tap (no node-drag, no pan distance) treat as click for selection on empty.
        draggingNodeID = nil
        isPanning = false
    }
}

// MARK: - NSView for scroll-wheel events (cmd-scroll = zoom; scroll = pan)
//
// Installs a local NSEvent monitor while the view is in the window so we can
// observe scrollWheel events without intercepting mouse events from SwiftUI.

private struct ScrollWheelCatcher: NSViewRepresentable {
    let onScroll: (NSEvent) -> Void

    func makeNSView(context: Context) -> CatcherView {
        let v = CatcherView()
        v.onScroll = onScroll
        return v
    }

    func updateNSView(_ nsView: CatcherView, context: Context) {
        nsView.onScroll = onScroll
    }

    final class CatcherView: NSView {
        var onScroll: ((NSEvent) -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, let w = self.window, event.window === w else { return event }
                let locInWindow = event.locationInWindow
                let locInSelf = self.convert(locInWindow, from: nil)
                if self.bounds.contains(locInSelf) {
                    self.onScroll?(event)
                }
                return event
            }
        }

        deinit {
            if let m = monitor { NSEvent.removeMonitor(m) }
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
