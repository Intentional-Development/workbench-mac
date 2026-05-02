import XCTest
@testable import WorkbenchMac

// MARK: - Proposal Model Tests (W24)
//
// Tests for ProposalModel.swift data structures and parsing.

final class ProposalModelTests: XCTestCase {
    
    func testProposalStatusEnum() {
        XCTAssertEqual(ProposalStatus.pending.rawValue, "pending")
        XCTAssertEqual(ProposalStatus.accepted.rawValue, "accepted")
        XCTAssertEqual(ProposalStatus.rejected.rawValue, "rejected")
        
        XCTAssertEqual(ProposalStatus.allCases.count, 3)
    }
    
    func testProposalOperationTypes() {
        XCTAssertEqual(ProposalOperationType.addDTO.description, "Add DTO")
        XCTAssertEqual(ProposalOperationType.removeDTO.description, "Remove DTO")
        XCTAssertEqual(ProposalOperationType.modifyDTOField.description, "Modify DTO Field")
        XCTAssertEqual(ProposalOperationType.changeKind.description, "Change Kind")
    }
    
    func testProposalSourceEnum() {
        XCTAssertEqual(ProposalSource.mcp.rawValue, "mcp")
        XCTAssertEqual(ProposalSource.cli.rawValue, "cli")
        XCTAssertEqual(ProposalSource.null.rawValue, "null")
        
        XCTAssertEqual(ProposalSource.mcp.description, "MCP Server")
        XCTAssertEqual(ProposalSource.cli.description, "CLI")
        XCTAssertEqual(ProposalSource.null.description, "Unknown")
    }
    
    func testAnyCodableStringValue() {
        let value = AnyCodable("test string")
        XCTAssertEqual(value.stringValue, "test string")
        XCTAssertNil(value.intValue)
        XCTAssertNil(value.boolValue)
    }
    
    func testAnyCodableIntValue() {
        let value = AnyCodable(42)
        XCTAssertEqual(value.intValue, 42)
        XCTAssertNil(value.stringValue)
    }
    
    func testAnyCodableBoolValue() {
        let value = AnyCodable(true)
        XCTAssertEqual(value.boolValue, true)
        XCTAssertNil(value.stringValue)
    }
    
    func testAnyCodableArrayValue() {
        let array = [1, 2, 3]
        let value = AnyCodable(array)
        XCTAssertNotNil(value.arrayValue)
        XCTAssertEqual(value.arrayValue?.count, 3)
    }
    
    func testAnyCodableDictValue() {
        let dict: [String: Any] = ["key": "value"]
        let value = AnyCodable(dict)
        XCTAssertNotNil(value.dictValue)
        XCTAssertEqual(value.dictValue?["key"] as? String, "value")
    }
}
