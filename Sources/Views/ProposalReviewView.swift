import SwiftUI

// MARK: - Proposal Review UI (W24)
//
// Full CRUD on proposals via MCP mutations.
// Three sections: Pending / Accepted / Rejected.
// Inline diff view showing before/after changes.
// Optimistic UI with rollback on failure.

@MainActor
final class ProposalReviewViewModel: ObservableObject {
    @Published var proposals: [Proposal] = []
    @Published var selectedProposal: Proposal?
    @Published var selectedStatus: ProposalStatus = .pending
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var rejectReason: String = ""
    @Published var isActionInProgress: Bool = false
    
    private let mcpClient: MCPClient
    
    init(mcpClient: MCPClient) {
        self.mcpClient = mcpClient
    }
    
    var filteredProposals: [Proposal] {
        proposals.filter { $0.status == selectedStatus }
    }
    
    func loadProposals() async {
        isLoading = true
        error = nil
        
        do {
            let result = try await mcpClient.listProposals()
            
            // Parse proposals from result
            let decoder = JSONDecoder()
            var parsed: [Proposal] = []
            
            for dict in result {
                if let data = try? JSONSerialization.data(withJSONObject: dict),
                   let proposal = try? decoder.decode(Proposal.self, from: data) {
                    parsed.append(proposal)
                }
            }
            
            proposals = parsed.sorted { $0.createdAt > $1.createdAt }
        } catch {
            self.error = "Failed to load proposals: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func acceptProposal(_ proposal: Proposal) async {
        isActionInProgress = true
        error = nil
        
        // Optimistic update
        let originalStatus = proposal.status
        if let index = proposals.firstIndex(where: { $0.id == proposal.id }) {
            var updated = proposal
            updated = Proposal(
                id: updated.id,
                status: .accepted,
                changes: updated.changes,
                reason: updated.reason,
                createdAt: updated.createdAt,
                updatedAt: ISO8601DateFormatter().string(from: Date()),
                auditTrail: updated.auditTrail
            )
            proposals[index] = updated
            selectedProposal = updated
        }
        
        do {
            _ = try await mcpClient.acceptProposal(id: proposal.id)
            // Refresh to get server state
            await loadProposals()
        } catch {
            self.error = "Failed to accept proposal: \(error.localizedDescription)"
            
            // Rollback on failure
            if let index = proposals.firstIndex(where: { $0.id == proposal.id }) {
                var updated = proposals[index]
                updated = Proposal(
                    id: updated.id,
                    status: originalStatus,
                    changes: updated.changes,
                    reason: updated.reason,
                    createdAt: updated.createdAt,
                    updatedAt: updated.updatedAt,
                    auditTrail: updated.auditTrail
                )
                proposals[index] = updated
                selectedProposal = updated
            }
        }
        
        isActionInProgress = false
    }
    
    func rejectProposal(_ proposal: Proposal, reason: String) async {
        isActionInProgress = true
        error = nil
        
        // Optimistic update
        let originalStatus = proposal.status
        if let index = proposals.firstIndex(where: { $0.id == proposal.id }) {
            var updated = proposal
            updated = Proposal(
                id: updated.id,
                status: .rejected,
                changes: updated.changes,
                reason: reason,
                createdAt: updated.createdAt,
                updatedAt: ISO8601DateFormatter().string(from: Date()),
                auditTrail: updated.auditTrail
            )
            proposals[index] = updated
            selectedProposal = updated
        }
        
        do {
            _ = try await mcpClient.rejectProposal(id: proposal.id, reason: reason)
            // Refresh to get server state
            await loadProposals()
        } catch {
            self.error = "Failed to reject proposal: \(error.localizedDescription)"
            
            // Rollback on failure
            if let index = proposals.firstIndex(where: { $0.id == proposal.id }) {
                var updated = proposals[index]
                updated = Proposal(
                    id: updated.id,
                    status: originalStatus,
                    changes: updated.changes,
                    reason: updated.reason,
                    createdAt: updated.createdAt,
                    updatedAt: updated.updatedAt,
                    auditTrail: updated.auditTrail
                )
                proposals[index] = updated
                selectedProposal = updated
            }
        }
        
        isActionInProgress = false
        rejectReason = ""
    }
}

struct ProposalReviewView: View {
    @StateObject private var model: ProposalReviewViewModel
    @StateObject private var mcpClient = MCPClient()
    
    init() {
        let client = MCPClient()
        _mcpClient = StateObject(wrappedValue: client)
        _model = StateObject(wrappedValue: ProposalReviewViewModel(mcpClient: client))
    }
    
    var body: some View {
        HSplitView {
            // Left: Status filter + proposal list
            VStack(alignment: .leading, spacing: 0) {
                // Status picker
                Picker("Status", selection: $model.selectedStatus) {
                    ForEach(ProposalStatus.allCases) { status in
                        Text(status.description).tag(status)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                Divider()
                
                // Proposal list
                if model.isLoading {
                    VStack {
                        ProgressView()
                        Text("Loading proposals...")
                            .foregroundStyle(.secondary)
                            .padding(.top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if model.filteredProposals.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No \(model.selectedStatus.description.lowercased()) proposals")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(model.filteredProposals, selection: $model.selectedProposal) { proposal in
                        ProposalListRow(proposal: proposal)
                    }
                }
            }
            .frame(minWidth: 250, idealWidth: 300, maxWidth: 400)
            
            // Right: Proposal detail
            VStack(alignment: .leading, spacing: 0) {
                if let proposal = model.selectedProposal {
                    ProposalDetailView(
                        proposal: proposal,
                        rejectReason: $model.rejectReason,
                        isActionInProgress: model.isActionInProgress,
                        onAccept: {
                            Task {
                                await model.acceptProposal(proposal)
                            }
                        },
                        onReject: { reason in
                            Task {
                                await model.rejectProposal(proposal, reason: reason)
                            }
                        }
                    )
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Select a proposal to view details")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                if let error = model.error {
                    Divider()
                    HStack {
                        Label("Error", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Dismiss") {
                            model.error = nil
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                }
            }
        }
        .task {
            if !mcpClient.isConnected {
                try? await mcpClient.connect()
            }
            await model.loadProposals()
        }
    }
}

struct ProposalListRow: View {
    let proposal: Proposal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(proposal.id)
                    .font(.system(.headline, design: .monospaced))
                Spacer()
                StatusBadge(status: proposal.status)
            }
            
            if let reason = proposal.reason {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Text("\(proposal.changes.count) change(s)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

struct StatusBadge: View {
    let status: ProposalStatus
    
    var body: some View {
        Text(status.description)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .cornerRadius(4)
    }
    
    private var backgroundColor: Color {
        switch status {
        case .pending: return .orange.opacity(0.2)
        case .accepted: return .green.opacity(0.2)
        case .rejected: return .red.opacity(0.2)
        }
    }
    
    private var foregroundColor: Color {
        switch status {
        case .pending: return .orange
        case .accepted: return .green
        case .rejected: return .red
        }
    }
}

struct ProposalDetailView: View {
    let proposal: Proposal
    @Binding var rejectReason: String
    let isActionInProgress: Bool
    let onAccept: () -> Void
    let onReject: (String) -> Void
    
    @State private var showRejectDialog = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(proposal.id)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Spacer()
                    StatusBadge(status: proposal.status)
                }
                
                if let reason = proposal.reason {
                    Text(reason)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 16) {
                    Label(proposal.createdAt, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Label("\(proposal.changes.count) changes", systemImage: "doc.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            
            Divider()
            
            // Changes (diff view)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(proposal.changes) { change in
                        ChangeDetailView(change: change)
                    }
                    
                    // Audit trail
                    if !proposal.auditTrail.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Audit Trail")
                                .font(.headline)
                            
                            ForEach(proposal.auditTrail) { entry in
                                AuditTrailEntryView(entry: entry)
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Actions
            if proposal.status == .pending {
                HStack {
                    Button("Accept") {
                        onAccept()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isActionInProgress)
                    
                    Button("Reject") {
                        showRejectDialog = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(isActionInProgress)
                    
                    if isActionInProgress {
                        ProgressView()
                            .controlSize(.small)
                    }
                    
                    Spacer()
                }
                .padding()
                .sheet(isPresented: $showRejectDialog) {
                    RejectDialogView(
                        reason: $rejectReason,
                        onReject: {
                            onReject(rejectReason)
                            showRejectDialog = false
                        },
                        onCancel: {
                            showRejectDialog = false
                        }
                    )
                }
            }
        }
    }
}

struct ChangeDetailView: View {
    let change: ProposalChange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(change.operationType.description)
                    .font(.headline)
                Spacer()
                if let nodeId = change.nodeId {
                    Text("Node: \(nodeId)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Before/After diff
            if let before = change.before, let after = change.after {
                HStack(alignment: .top, spacing: 16) {
                    // Before
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Before")
                            .font(.caption)
                            .foregroundStyle(.red)
                        Text(formatJSON(before))
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // After
                    VStack(alignment: .leading, spacing: 4) {
                        Text("After")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text(formatJSON(after))
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if let after = change.after {
                VStack(alignment: .leading, spacing: 4) {
                    Text("New")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text(formatJSON(after))
                        .font(.system(.caption, design: .monospaced))
                        .padding(8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(4)
                }
            } else if let before = change.before {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Removed")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Text(formatJSON(before))
                        .font(.system(.caption, design: .monospaced))
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func formatJSON(_ dict: [String: AnyCodable]) -> String {
        let mapped = dict.mapValues { $0.value }
        if let data = try? JSONSerialization.data(withJSONObject: mapped, options: .prettyPrinted),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "\(mapped)"
    }
}

struct AuditTrailEntryView: View {
    let entry: AuditTrailEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(entry.action)
                        .font(.system(.caption, design: .monospaced))
                    Spacer()
                    Text(entry.source.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                if let actor = entry.actor {
                    Text("by \(actor)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                
                Text(entry.timestamp)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(8)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(4)
    }
}

struct RejectDialogView: View {
    @Binding var reason: String
    let onReject: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Reject Proposal")
                .font(.headline)
            
            Text("Please provide a reason for rejecting this proposal:")
                .font(.body)
            
            TextEditor(text: $reason)
                .frame(height: 100)
                .border(Color.gray.opacity(0.3))
            
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Reject") {
                    onReject()
                }
                .buttonStyle(.borderedProminent)
                .disabled(reason.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
