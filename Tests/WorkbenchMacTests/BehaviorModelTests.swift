import XCTest
@testable import WorkbenchMac

final class BehaviorModelTests: XCTestCase {
    
    func testBehaviorRoleEnumeration() {
        XCTAssertEqual(BehaviorRole.allCases.count, 6)
        XCTAssertEqual(BehaviorRole.entity.rawValue, "entity")
        XCTAssertEqual(BehaviorRole.valueObject.rawValue, "value-object")
        XCTAssertEqual(BehaviorRole.command.rawValue, "command")
        XCTAssertEqual(BehaviorRole.event.rawValue, "event")
        XCTAssertEqual(BehaviorRole.queryResult.rawValue, "query-result")
        XCTAssertEqual(BehaviorRole.dtoOnly.rawValue, "dto-only")
    }
    
    func testBehaviorRoleColors() {
        XCTAssertEqual(BehaviorRole.entity.color, "blue")
        XCTAssertEqual(BehaviorRole.valueObject.color, "green")
        XCTAssertEqual(BehaviorRole.command.color, "orange")
        XCTAssertEqual(BehaviorRole.event.color, "red")
        XCTAssertEqual(BehaviorRole.queryResult.color, "purple")
        XCTAssertEqual(BehaviorRole.dtoOnly.color, "gray")
    }
    
    func testBehaviorRoleDescription() {
        XCTAssertEqual(BehaviorRole.entity.description, "Entity")
        XCTAssertEqual(BehaviorRole.valueObject.description, "Value Object")
        XCTAssertEqual(BehaviorRole.command.description, "Command")
        XCTAssertEqual(BehaviorRole.event.description, "Event")
        XCTAssertEqual(BehaviorRole.queryResult.description, "Query Result")
        XCTAssertEqual(BehaviorRole.dtoOnly.description, "DTO Only")
    }
    
    func testNodeBehaviorRoleParsing() {
        // Node with behavior classification in confidence.metadata
        let behaviorMetadata: [String: JSONValue] = ["behavior": .string("entity")]
        let confidence = Confidence(
            score: 0.95,
            model: "gpt-4",
            run_id: "test-run",
            rationale: "Test",
            metadata: behaviorMetadata
        )
        
        let node = GraphNode(
            id: "test-node",
            kind: .entity,
            state: .accepted,
            created_by: .ai,
            props: ["name": .string("TestEntity")],
            source_anchors: nil,
            confidence: confidence
        )
        
        XCTAssertEqual(node.behaviorRole, .entity)
    }
    
    func testNodeWithoutBehaviorRole() {
        let node = GraphNode(
            id: "test-node",
            kind: .entity,
            state: .accepted,
            created_by: .ai,
            props: ["name": .string("TestEntity")],
            source_anchors: nil,
            confidence: nil
        )
        
        XCTAssertNil(node.behaviorRole)
    }
    
    func testBehaviorDistribution() {
        // Create test graph with mixed behavior roles
        let nodes = [
            makeNode(id: "n1", behavior: "entity"),
            makeNode(id: "n2", behavior: "entity"),
            makeNode(id: "n3", behavior: "command"),
            makeNode(id: "n4", behavior: "event"),
            makeNode(id: "n5", behavior: nil),  // unclassified
        ]
        
        let graph = Graph(
            version: "0.1.9",
            metadata: nil,
            nodes: nodes,
            edges: []
        )
        
        let distribution = graph.behaviorDistribution
        
        // Should have 3 roles (entity, command, event)
        XCTAssertEqual(distribution.count, 3)
        
        // Check entity distribution
        if let entityDist = distribution.first(where: { $0.role == .entity }) {
            XCTAssertEqual(entityDist.count, 2)
            XCTAssertEqual(entityDist.percentage, 50.0, accuracy: 0.1)
        } else {
            XCTFail("Expected entity distribution")
        }
        
        // Check command distribution
        if let commandDist = distribution.first(where: { $0.role == .command }) {
            XCTAssertEqual(commandDist.count, 1)
            XCTAssertEqual(commandDist.percentage, 25.0, accuracy: 0.1)
        } else {
            XCTFail("Expected command distribution")
        }
        
        // Check unclassified count
        XCTAssertEqual(graph.unclassifiedNodeCount, 1)
    }
    
    // MARK: - Helpers
    
    private func makeNode(id: String, behavior: String?) -> GraphNode {
        let confidence: Confidence?
        if let b = behavior {
            let metadata: [String: JSONValue] = ["behavior": .string(b)]
            confidence = Confidence(
                score: 0.9,
                model: "test",
                run_id: "test-run",
                rationale: "test",
                metadata: metadata
            )
        } else {
            confidence = nil
        }
        
        return GraphNode(
            id: id,
            kind: .entity,
            state: .accepted,
            created_by: .ai,
            props: ["name": .string(id)],
            source_anchors: nil,
            confidence: confidence
        )
    }
}
