import Foundation

// MARK: - Corpus Configuration

enum DriftCorpus: String, CaseIterable, Identifiable {
    case realworld
    case n8n
    case fireflyIii = "firefly-iii"
    case localsend

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .realworld:   return "realworld"
        case .n8n:         return "n8n"
        case .fireflyIii:  return "firefly-iii"
        case .localsend:   return "localsend"
        }
    }

    /// `--source` argument value (corpus=path)
    var sourceArg: String {
        switch self {
        case .realworld:   return "realworld=realworld"
        case .n8n:         return "n8n=n8n"
        case .fireflyIii:  return "firefly=firefly-iii"
        case .localsend:   return "localsend=localsend"
        }
    }

    /// Path to the graph JSON relative to workspace root
    var graphPath: String {
        switch self {
        case .realworld:   return "realworld-idl/intent/extracted/realworld-graph.json"
        case .n8n:         return "n8n-idl/intent/extracted/graph.json"
        case .fireflyIii:  return "firefly-iii-idl/intent/extracted/graph.json"
        case .localsend:   return "localsend-idl/intent/extracted/graph.json"
        }
    }
}

// MARK: - Wire Output Models

struct DriftEntry: Codable, Identifiable {
    var id: String { node_id }
    let node_id: String
    let node_kind: String
    let verdict: String
    let uri: String?
    let resolved_path: String?
    let note: String?

    // Convenience kind display
    var kindDisplay: String { node_kind }
}

struct DriftSweepOutput: Codable {
    let graph_path: String
    let source_root: String
    let entries: [DriftEntry]
}

// MARK: - Verdict helpers

enum DriftVerdict: String, CaseIterable, Identifiable {
    case aligned       = "aligned"
    case shifted       = "shifted"
    case missing       = "missing"
    case newInCode     = "new-in-code"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .aligned:   return "Aligned"
        case .shifted:   return "Shifted"
        case .missing:   return "Missing"
        case .newInCode: return "New-in-code"
        }
    }

    var color: String {
        switch self {
        case .aligned:   return "green"
        case .shifted:   return "yellow"
        case .missing:   return "red"
        case .newInCode: return "blue"
        }
    }
}

// MARK: - Sort State

enum DriftSortField: String, CaseIterable {
    case nodeId  = "node_id"
    case kind    = "kind"
    case verdict = "verdict"
    case uri     = "uri"
}
