import Foundation

// MARK: - Proposal Model (W24)
//
// Models the IDL proposal system for graph mutations.
// Proposals can add/remove/modify DTOs or change node kinds.
// Each proposal has an audit trail showing source attribution.

public enum ProposalStatus: String, Codable, CaseIterable, Identifiable {
    case pending = "pending"
    case accepted = "accepted"
    case rejected = "rejected"
    
    public var id: String { rawValue }
    
    public var description: String {
        switch self {
        case .pending: return "Pending"
        case .accepted: return "Accepted"
        case .rejected: return "Rejected"
        }
    }
}

public enum ProposalOperationType: String, Codable {
    case addDTO = "add_dto"
    case removeDTO = "remove_dto"
    case modifyDTOField = "modify_dto_field"
    case changeKind = "change_kind"
    case addNode = "add_node"
    case removeNode = "remove_node"
    case updateNode = "update_node"
    case addEdge = "add_edge"
    case removeEdge = "remove_edge"
    
    public var description: String {
        switch self {
        case .addDTO: return "Add DTO"
        case .removeDTO: return "Remove DTO"
        case .modifyDTOField: return "Modify DTO Field"
        case .changeKind: return "Change Kind"
        case .addNode: return "Add Node"
        case .removeNode: return "Remove Node"
        case .updateNode: return "Update Node"
        case .addEdge: return "Add Edge"
        case .removeEdge: return "Remove Edge"
        }
    }
}

public enum ProposalSource: String, Codable {
    case mcp = "mcp"
    case cli = "cli"
    case null = "null"
    
    public var description: String {
        switch self {
        case .mcp: return "MCP Server"
        case .cli: return "CLI"
        case .null: return "Unknown"
        }
    }
}

// MARK: - Proposal Change (Before/After Diff)

public struct ProposalChange: Codable, Identifiable, Hashable {
    public let id: String
    public let operationType: ProposalOperationType
    public let before: [String: AnyCodable]?
    public let after: [String: AnyCodable]?
    public let nodeId: String?
    public let edgeId: String?
    
    public init(
        id: String,
        operationType: ProposalOperationType,
        before: [String: AnyCodable]?,
        after: [String: AnyCodable]?,
        nodeId: String? = nil,
        edgeId: String? = nil
    ) {
        self.id = id
        self.operationType = operationType
        self.before = before
        self.after = after
        self.nodeId = nodeId
        self.edgeId = edgeId
    }
    
    public static func == (lhs: ProposalChange, rhs: ProposalChange) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Audit Trail Entry

public struct AuditTrailEntry: Codable, Identifiable, Hashable {
    public let id: String
    public let timestamp: String
    public let source: ProposalSource
    public let actor: String?
    public let action: String
    public let metadata: [String: AnyCodable]?
    
    public init(
        id: String,
        timestamp: String,
        source: ProposalSource,
        actor: String?,
        action: String,
        metadata: [String: AnyCodable]?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.actor = actor
        self.action = action
        self.metadata = metadata
    }
    
    public static func == (lhs: AuditTrailEntry, rhs: AuditTrailEntry) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Proposal

public struct Proposal: Codable, Identifiable, Hashable {
    public let id: String
    public let status: ProposalStatus
    public let changes: [ProposalChange]
    public let reason: String?
    public let createdAt: String
    public let updatedAt: String?
    public let auditTrail: [AuditTrailEntry]
    
    public init(
        id: String,
        status: ProposalStatus,
        changes: [ProposalChange],
        reason: String?,
        createdAt: String,
        updatedAt: String?,
        auditTrail: [AuditTrailEntry]
    ) {
        self.id = id
        self.status = status
        self.changes = changes
        self.reason = reason
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.auditTrail = auditTrail
    }
    
    public static func == (lhs: Proposal, rhs: Proposal) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - AnyCodable Helper

public struct AnyCodable: Codable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode AnyCodable"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            let context = EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Cannot encode value of type \(type(of: value))"
            )
            throw EncodingError.invalidValue(value, context)
        }
    }
    
    public var stringValue: String? {
        value as? String
    }
    
    public var intValue: Int? {
        value as? Int
    }
    
    public var doubleValue: Double? {
        value as? Double
    }
    
    public var boolValue: Bool? {
        value as? Bool
    }
    
    public var arrayValue: [Any]? {
        value as? [Any]
    }
    
    public var dictValue: [String: Any]? {
        value as? [String: Any]
    }
}
