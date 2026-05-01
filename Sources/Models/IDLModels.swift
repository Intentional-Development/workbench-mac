import Foundation

// MARK: - IDL AST Models (Mirror of IDL spec)

struct IDLDocument: Codable, Identifiable {
    let id: String
    let moduleName: String
    let version: String
    let blocks: [IDLBlock]
}

enum IDLBlock: Codable {
    case intent(Intent)
    case scope(Scope)
    case entity(Entity)
    case endpoint(Endpoint)
    case rule(Rule)
    case decision(Decision)
    case uxFlow(UXFlow)
    case uxComponent(UXComponent)
    case stateMachine(StateMachine)
    case variant(Variant)
    case execution(Execution)
}

struct Intent: Codable, Identifiable {
    let id: String
    let name: String
    let goal: String
    let outcome: String
    let actors: [String]
    let businessValue: String?
    let priority: String
}

struct Scope: Codable, Identifiable {
    let id: String
    let name: String
    let intent: String
    let includes: [String]
    let excludes: [String]
}

struct Entity: Codable, Identifiable {
    let id: String
    let name: String
    let fields: [EntityField]
    let relationships: [EntityRelationship]?
}

struct EntityField: Codable, Identifiable {
    let id: String
    let name: String
    let type: String
    let constraint: String // required, optional
    let defaultValue: String?
}

struct EntityRelationship: Codable {
    let type: String // has_one, has_many, belongs_to
    let target: String
}

struct Endpoint: Codable, Identifiable {
    let id: String
    let method: String // GET, POST, PUT, DELETE, PATCH
    let path: String
    let intent: String?
    let request: [EntityField]?
    let response: [EntityField]?
    let errors: [Int]
}

struct Rule: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let condition: String
    let action: String
}

struct Decision: Codable, Identifiable {
    let id: String
    let title: String
    let status: String // proposed, accepted, rejected, deprecated
    let context: String
    let decision: String
    let consequences: String
    let alternatives: [String]?
}

struct UXFlow: Codable, Identifiable {
    let id: String
    let name: String
    let actors: [String]
    let trigger: String
    let steps: [FlowStep]
    let success: String
    let failure: String
}

struct FlowStep: Codable, Identifiable {
    let id: String
    let description: String
    let actor: String?
}

struct UXComponent: Codable, Identifiable {
    let id: String
    let name: String
    let type: String // page, modal, form, list, etc.
    let purpose: String
    let inputs: [String]?
    let outputs: [String]?
    let children: [String]?
}

struct StateMachine: Codable, Identifiable {
    let id: String
    let name: String
    let states: [StateMachineState]
    let transitions: [Transition]
}

struct StateMachineState: Codable, Identifiable {
    let id: String
    let name: String
    let isInitial: Bool
    let isFinal: Bool
}

struct Transition: Codable, Identifiable {
    let id: String
    let from: String
    let to: String
    let event: String
    let guardCondition: String?
}

struct Variant: Codable, Identifiable {
    let id: String
    let name: String
    let cases: [VariantCase]
}

struct VariantCase: Codable, Identifiable {
    let id: String
    let name: String
    let fields: [EntityField]?
}

struct Execution: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let steps: [ExecutionStep]
}

struct ExecutionStep: Codable, Identifiable {
    let id: String
    let description: String
    let command: String?
}
