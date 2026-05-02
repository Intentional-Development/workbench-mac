import Foundation

// MARK: - Behavior Classification Model (Schema v0.1.9)
//
// Models the `confidence.metadata.behavior` field introduced in v0.1.9.
// Classifies nodes into 6 DDD-style roles: entity, value-object, command, event, query-result, dto-only.

public enum BehaviorRole: String, Codable, CaseIterable, Identifiable, CustomStringConvertible {
    case entity = "entity"
    case valueObject = "value-object"
    case command = "command"
    case event = "event"
    case queryResult = "query-result"
    case dtoOnly = "dto-only"
    
    public var id: String { rawValue }
    
    public var description: String {
        switch self {
        case .entity: return "Entity"
        case .valueObject: return "Value Object"
        case .command: return "Command"
        case .event: return "Event"
        case .queryResult: return "Query Result"
        case .dtoOnly: return "DTO Only"
        }
    }
    
    /// Color-coding per W23 spec: entity=blue, value-object=green, command=orange, event=red, query-result=purple, dto-only=gray
    public var color: String {
        switch self {
        case .entity: return "blue"
        case .valueObject: return "green"
        case .command: return "orange"
        case .event: return "red"
        case .queryResult: return "purple"
        case .dtoOnly: return "gray"
        }
    }
}

// MARK: - Extended Graph Models for Behavior

public extension GraphNode {
    /// Extracts behavior role from confidence.metadata.behavior (v0.1.9+)
    var behaviorRole: BehaviorRole? {
        guard let metadata = confidence?.metadata,
              let behaviorValue = metadata["behavior"],
              let behaviorString = behaviorValue.stringValue else {
            return nil
        }
        return BehaviorRole(rawValue: behaviorString)
    }
}

// MARK: - Behavior Distribution Stats

public struct BehaviorDistribution: Identifiable {
    public let id: String
    public let role: BehaviorRole
    public let count: Int
    public let percentage: Double
    public let nodes: [GraphNode]
    
    public init(role: BehaviorRole, count: Int, percentage: Double, nodes: [GraphNode]) {
        self.id = role.rawValue
        self.role = role
        self.count = count
        self.percentage = percentage
        self.nodes = nodes
    }
}

public extension Graph {
    /// Groups nodes by behavior role and computes distribution stats
    var behaviorDistribution: [BehaviorDistribution] {
        let nodesWithBehavior = nodes.filter { $0.behaviorRole != nil }
        let total = Double(nodesWithBehavior.count)
        
        guard total > 0 else { return [] }
        
        let grouped = Dictionary(grouping: nodesWithBehavior) { $0.behaviorRole! }
        
        return BehaviorRole.allCases.compactMap { role in
            guard let roleNodes = grouped[role] else { return nil }
            let count = roleNodes.count
            let percentage = (Double(count) / total) * 100.0
            return BehaviorDistribution(
                role: role,
                count: count,
                percentage: percentage,
                nodes: roleNodes.sorted { $0.id < $1.id }
            )
        }
        .sorted { $0.count > $1.count }
    }
    
    /// Count of nodes without behavior classification
    var unclassifiedNodeCount: Int {
        nodes.filter { $0.behaviorRole == nil }.count
    }
}
