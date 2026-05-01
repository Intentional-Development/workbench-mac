import SwiftUI

// MARK: - View Model

@MainActor
final class DriftDashboardViewModel: ObservableObject {
    @Published var selectedCorpus: DriftCorpus = .realworld
    @Published var entries: [DriftEntry] = []
    @Published var isRunning = false
    @Published var errorMessage: String?

    // Filter state — all on by default
    @Published var activeVerdicts: Set<String> = Set(DriftVerdict.allCases.map(\.rawValue))

    // Sort state
    @Published var sortField: DriftSortField = .verdict
    @Published var sortAscending = true

    // Per-corpus result cache (mirrors service cache in UI layer)
    private var resultCache: [DriftCorpus: [DriftEntry]] = [:]

    // MARK: - Computed

    var filteredEntries: [DriftEntry] {
        let filtered = entries.filter { activeVerdicts.contains($0.verdict) }
        return filtered.sorted { a, b in
            let cmp: Bool
            switch sortField {
            case .nodeId:  cmp = a.node_id < b.node_id
            case .kind:    cmp = a.node_kind < b.node_kind
            case .verdict: cmp = a.verdict < b.verdict
            case .uri:     cmp = (a.uri ?? "") < (b.uri ?? "")
            }
            return sortAscending ? cmp : !cmp
        }
    }

    func count(for verdict: DriftVerdict) -> Int {
        entries.filter { $0.verdict == verdict.rawValue }.count
    }

    // MARK: - Actions

    func selectCorpus(_ corpus: DriftCorpus) {
        selectedCorpus = corpus
        // Load from cache if available
        if let cached = resultCache[corpus] {
            entries = cached
            errorMessage = nil
        } else {
            entries = []
            errorMessage = nil
        }
    }

    func runSweep() {
        isRunning = true
        errorMessage = nil
        Task {
            do {
                let result = try await DriftSweepService.shared.runSweep(corpus: selectedCorpus)
                resultCache[selectedCorpus] = result
                entries = result
            } catch {
                errorMessage = error.localizedDescription
            }
            isRunning = false
        }
    }

    func toggleVerdict(_ verdict: DriftVerdict) {
        if activeVerdicts.contains(verdict.rawValue) {
            activeVerdicts.remove(verdict.rawValue)
        } else {
            activeVerdicts.insert(verdict.rawValue)
        }
    }

    func toggleSort(_ field: DriftSortField) {
        if sortField == field {
            sortAscending.toggle()
        } else {
            sortField = field
            sortAscending = true
        }
    }
}

// MARK: - Drift Dashboard View

struct DriftDashboardView: View {
    @StateObject private var vm = DriftDashboardViewModel()

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            summaryRow
            Divider()
            filterChipsRow
            Divider()
            if vm.entries.isEmpty && !vm.isRunning {
                emptyState
            } else {
                nodeTable
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Text("Drift Dashboard")
                .font(.headline)

            Spacer()

            Picker("Corpus", selection: Binding(
                get: { vm.selectedCorpus },
                set: { vm.selectCorpus($0) }
            )) {
                ForEach(DriftCorpus.allCases) { corpus in
                    Text(corpus.displayName).tag(corpus)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 160)

            Button(action: { vm.runSweep() }) {
                if vm.isRunning {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.7)
                        Text("Running…")
                    }
                } else {
                    Label("Run sweep", systemImage: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.isRunning)

            if let err = vm.errorMessage {
                Text(err)
                    .foregroundColor(.red)
                    .font(.caption)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Summary Counts

    private var summaryRow: some View {
        HStack(spacing: 24) {
            ForEach(DriftVerdict.allCases) { verdict in
                verdictBadge(verdict: verdict, count: vm.count(for: verdict))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func verdictBadge(verdict: DriftVerdict, count: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(colorFor(verdict))
            Text(verdict.label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(colorFor(verdict).opacity(0.1))
        .cornerRadius(10)
    }

    // MARK: - Filter Chips

    private var filterChipsRow: some View {
        HStack(spacing: 8) {
            Text("Show:")
                .font(.caption)
                .foregroundColor(.secondary)
            ForEach(DriftVerdict.allCases) { verdict in
                filterChip(verdict: verdict)
            }
            Spacer()
            Text("\(vm.filteredEntries.count) nodes")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func filterChip(verdict: DriftVerdict) -> some View {
        let active = vm.activeVerdicts.contains(verdict.rawValue)
        return Button(action: { vm.toggleVerdict(verdict) }) {
            Text(verdict.label)
                .font(.caption)
                .fontWeight(active ? .semibold : .regular)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(active ? colorFor(verdict).opacity(0.2) : Color(NSColor.controlColor))
                .foregroundColor(active ? colorFor(verdict) : .secondary)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(active ? colorFor(verdict) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.badge.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No data yet")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("Pick a corpus and press \u{201C}Run sweep\u{201D}.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Node Table

    private var nodeTable: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                headerCell("Node ID", field: .nodeId, flex: 3)
                Divider().frame(height: 28)
                headerCell("Kind", field: .kind, flex: 1)
                Divider().frame(height: 28)
                headerCell("Verdict", field: .verdict, flex: 1)
                Divider().frame(height: 28)
                headerCell("URI", field: .uri, flex: 3)
            }
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(vm.filteredEntries.enumerated()), id: \.element.id) { idx, entry in
                        nodeRow(entry: entry, isEven: idx.isMultiple(of: 2))
                        Divider()
                    }
                }
            }
        }
    }

    private func headerCell(_ label: String, field: DriftSortField, flex: Int) -> some View {
        Button(action: { vm.toggleSort(field) }) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption)
                    .fontWeight(.semibold)
                if vm.sortField == field {
                    Image(systemName: vm.sortAscending ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private func nodeRow(entry: DriftEntry, isEven: Bool) -> some View {
        HStack(spacing: 0) {
            Text(entry.node_id)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)

            Divider()

            Text(entry.node_kind)
                .font(.caption)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)

            Divider()

            HStack(spacing: 4) {
                Circle()
                    .fill(colorFor(entry.verdict))
                    .frame(width: 7, height: 7)
                Text(entry.verdict)
                    .font(.caption)
                    .foregroundColor(colorFor(entry.verdict))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)

            Divider()

            Text(entry.uri ?? "—")
                .font(.system(.caption2, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
        }
        .background(isEven ? Color.clear : Color(NSColor.controlBackgroundColor).opacity(0.4))
    }

    // MARK: - Helpers

    private func colorFor(_ verdict: DriftVerdict) -> Color {
        switch verdict {
        case .aligned:   return .green
        case .shifted:   return .orange
        case .missing:   return .red
        case .newInCode: return .blue
        }
    }

    private func colorFor(_ verdictString: String) -> Color {
        guard let v = DriftVerdict(rawValue: verdictString) else { return .secondary }
        return colorFor(v)
    }
}
