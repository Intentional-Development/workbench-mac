import Foundation

// MARK: - Semantic Graph Model
//
// Mirrors IDL/schemas/semantic-graph.schema.json (v0.1.0, 18 NodeKind / 18 EdgeKind).
// Permissive: unknown enum values decode to .unknown(rawValue) so extension blocks
// from future kernel versions don't fail the load.

// MARK: NodeKind

public enum NodeKind: Hashable, Codable, CustomStringConvertible {
    case intent, scope, entity, aggregate, variant, constraints
    case event, operation, stateMachine, rule, invariant, policy
    case api, accessPattern, mapping, traceLink, decision, verification
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .intent: return "intent"
        case .scope: return "scope"
        case .entity: return "entity"
        case .aggregate: return "aggregate"
        case .variant: return "variant"
        case .constraints: return "constraints"
        case .event: return "event"
        case .operation: return "operation"
        case .stateMachine: return "state_machine"
        case .rule: return "rule"
        case .invariant: return "invariant"
        case .policy: return "policy"
        case .api: return "api"
        case .accessPattern: return "access_pattern"
        case .mapping: return "mapping"
        case .traceLink: return "trace_link"
        case .decision: return "decision"
        case .verification: return "verification"
        case .unknown(let s): return s
        }
    }

    public init(rawValue: String) {
        switch rawValue {
        case "intent": self = .intent
        case "scope": self = .scope
        case "entity": self = .entity
        case "aggregate": self = .aggregate
        case "variant": self = .variant
        case "constraints": self = .constraints
        case "event": self = .event
        case "operation": self = .operation
        case "state_machine": self = .stateMachine
        case "rule": self = .rule
        case "invariant": self = .invariant
        case "policy": self = .policy
        case "api": self = .api
        case "access_pattern": self = .accessPattern
        case "mapping": self = .mapping
        case "trace_link": self = .traceLink
        case "decision": self = .decision
        case "verification": self = .verification
        default: self = .unknown(rawValue)
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        self = NodeKind(rawValue: try c.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }

    public var description: String { rawValue }

    public static let known: [NodeKind] = [
        .intent, .scope, .entity, .aggregate, .variant, .constraints,
        .event, .operation, .stateMachine, .rule, .invariant, .policy,
        .api, .accessPattern, .mapping, .traceLink, .decision, .verification
    ]
}

// MARK: EdgeKind

public enum EdgeKind: Hashable, Codable, CustomStringConvertible {
    case realizes, verifies, triggers, emits, handles, constrains
    case tracesTo, extractedFrom, supersedes, decides, implements
    case belongsTo, variantOf, transitions, queries, authorizes
    case contains, derivesFrom
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .realizes: return "realizes"
        case .verifies: return "verifies"
        case .triggers: return "triggers"
        case .emits: return "emits"
        case .handles: return "handles"
        case .constrains: return "constrains"
        case .tracesTo: return "traces_to"
        case .extractedFrom: return "extracted_from"
        case .supersedes: return "supersedes"
        case .decides: return "decides"
        case .implements: return "implements"
        case .belongsTo: return "belongs_to"
        case .variantOf: return "variant_of"
        case .transitions: return "transitions"
        case .queries: return "queries"
        case .authorizes: return "authorizes"
        case .contains: return "contains"
        case .derivesFrom: return "derives_from"
        case .unknown(let s): return s
        }
    }

    public init(rawValue: String) {
        switch rawValue {
        case "realizes": self = .realizes
        case "verifies": self = .verifies
        case "triggers": self = .triggers
        case "emits": self = .emits
        case "handles": self = .handles
        case "constrains": self = .constrains
        case "traces_to": self = .tracesTo
        case "extracted_from": self = .extractedFrom
        case "supersedes": self = .supersedes
        case "decides": self = .decides
        case "implements": self = .implements
        case "belongs_to": self = .belongsTo
        case "variant_of": self = .variantOf
        case "transitions": self = .transitions
        case "queries": self = .queries
        case "authorizes": self = .authorizes
        case "contains": self = .contains
        case "derives_from": self = .derivesFrom
        default: self = .unknown(rawValue)
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        self = EdgeKind(rawValue: try c.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }

    public var description: String { rawValue }
}

// MARK: NodeState

public enum NodeState: String, Codable, CaseIterable, Hashable {
    case accepted, proposed, inferred, questioned, rejected, drifted
}

public enum CreatedBy: String, Codable, Hashable {
    case human, ai, tool, `import`
}

// MARK: JSON value (for free-form props)

public indirect enum JSONValue: Codable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let i = try? c.decode(Int.self) { self = .int(i); return }
        if let d = try? c.decode(Double.self) { self = .double(d); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let a = try? c.decode([JSONValue].self) { self = .array(a); return }
        if let o = try? c.decode([String: JSONValue].self) { self = .object(o); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON value")
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .int(let i): try c.encode(i)
        case .double(let d): try c.encode(d)
        case .bool(let b): try c.encode(b)
        case .null: try c.encodeNil()
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }

    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    public var arrayValue: [JSONValue]? {
        if case .array(let a) = self { return a }
        return nil
    }

    public var objectValue: [String: JSONValue]? {
        if case .object(let o) = self { return o }
        return nil
    }

    /// Pretty-printed single-line representation, e.g. for inspector display.
    public var displayString: String {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        case .bool(let b): return String(b)
        case .null: return "null"
        case .array(let a):
            return "[" + a.map { $0.displayString }.joined(separator: ", ") + "]"
        case .object(let o):
            let parts = o.map { "\($0.key): \($0.value.displayString)" }
            return "{" + parts.joined(separator: ", ") + "}"
        }
    }
}

// MARK: Source anchors / confidence

public struct SourceRange: Codable, Hashable {
    public let start_line: Int?
    public let end_line: Int?
    public let start_col: Int?
    public let end_col: Int?
}

public struct SourceAnchor: Codable, Hashable, Identifiable {
    public let uri: String
    public let hash: String?
    public let range: SourceRange?

    public var id: String {
        "\(uri)#\(hash ?? "")#\(range?.start_line ?? -1)-\(range?.end_line ?? -1)"
    }
}

public struct Confidence: Codable, Hashable {
    public let score: Double?
    public let model: String?
    public let run_id: String?
    public let rationale: String?
    public let metadata: [String: JSONValue]?  // v0.1.9: behavior classification
}

// MARK: Node / Edge / Graph

public struct GraphNode: Codable, Identifiable, Hashable {
    public let id: String
    public let kind: NodeKind
    public let state: NodeState
    public let created_by: CreatedBy?
    public let props: [String: JSONValue]?
    public let source_anchors: [SourceAnchor]?
    public let confidence: Confidence?

    public var behaviorClassification: String? {
        props?["behavior_classification"]?.stringValue
    }

    /// Best-effort short label for the node — uses props.name / props.statement / id.
    public var displayLabel: String {
        if let s = props?["name"]?.stringValue { return s }
        if let s = props?["statement"]?.stringValue { return s }
        if let s = props?["title"]?.stringValue { return s }
        return id
    }
    
    /// Short label for nodes — uses props.name
    public var name: String {
        displayLabel
    }
}

public struct GraphEdge: Codable, Identifiable, Hashable {
    public let id: String?
    public let from: String
    public let to: String
    public let kind: EdgeKind
    public let props: [String: JSONValue]?

    public var stableID: String { id ?? "\(from)->\(kind.rawValue)->\(to)" }
}

public struct GraphMetadata: Codable, Hashable {
    public let project: String?
    public let extractor: String?
    public let extracted_at: String?
    public let run_id: String?
    public let corpus: String?
    public let wave: String?
    public let kernel_version: String?
}

public struct Graph: Codable {
    public let version: String?
    public let metadata: GraphMetadata?
    public let nodes: [GraphNode]
    public let edges: [GraphEdge]
}

// MARK: Loader

public enum GraphLoadError: Error, LocalizedError {
    case fileUnreadable(URL, underlying: Error)
    case decode(URL, underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .fileUnreadable(let url, let e):
            return "Cannot read \(url.lastPathComponent): \(e.localizedDescription)"
        case .decode(let url, let e):
            return "Cannot decode \(url.lastPathComponent): \(e.localizedDescription)"
        }
    }
}

public func loadGraph(at url: URL) -> Result<Graph, Error> {
    let data: Data
    do {
        data = try Data(contentsOf: url)
    } catch {
        return .failure(GraphLoadError.fileUnreadable(url, underlying: error))
    }
    do {
        let g = try JSONDecoder().decode(Graph.self, from: data)
        return .success(g)
    } catch {
        return .failure(GraphLoadError.decode(url, underlying: error))
    }
}
