import XCTest
@testable import WorkbenchMac

final class IDLCoreFFITests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Ensure FFI mode is enabled for these tests
        setenv("IDL_USE_CLI", "0", 1)
    }
    
    override func tearDown() {
        unsetenv("IDL_USE_CLI")
        super.tearDown()
    }
    
    func testParseGraphViaFFI_NonexistentPath() async throws {
        let core = IDLCore.shared
        
        do {
            _ = try await core.parseGraph(path: "/nonexistent/path/12345")
            XCTFail("Should throw for nonexistent path")
        } catch let error as IDLCoreError {
            switch error {
            case .ffiError(let msg):
                XCTAssertTrue(msg.contains("does not exist"), "Error message should mention path doesn't exist, got: \(msg)")
            default:
                XCTFail("Expected ffiError, got: \(error)")
            }
        }
    }
    
    func testParseGraphViaFFI_ValidPath() async throws {
        // Create a temp directory with a minimal .idl file
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("idl-test-\(UUID().uuidString)")
        
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let idlFile = tempDir.appendingPathComponent("test.idl")
        let idlContent = """
        intent BasicTest {
            goal: "Test parse_graph FFI"
        }
        """
        try idlContent.write(to: idlFile, atomically: true, encoding: .utf8)
        
        let core = IDLCore.shared
        let result = try await core.parseGraph(path: tempDir.path)
        
        // Should return valid JSON
        guard let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Result should be valid JSON")
            return
        }
        
        // Should have nodes and edges keys
        XCTAssertNotNil(json["nodes"], "JSON should have 'nodes' key")
        XCTAssertNotNil(json["edges"], "JSON should have 'edges' key")
        
        // Should have at least one node (BasicTest intent)
        if let nodes = json["nodes"] as? [String: Any] {
            XCTAssertGreaterThan(nodes.count, 0, "Should have at least one node")
        }
    }
    
    func testFFIFallbackToggle() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("idl-test-\(UUID().uuidString)")
        
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let idlFile = tempDir.appendingPathComponent("test.idl")
        let idlContent = """
        intent FallbackTest {
            goal: "Test CLI fallback"
        }
        """
        try idlContent.write(to: idlFile, atomically: true, encoding: .utf8)
        
        // Test FFI mode
        setenv("IDL_USE_CLI", "0", 1)
        let core1 = IDLCore.shared
        let ffiResult = try await core1.parseGraph(path: tempDir.path)
        XCTAssertFalse(ffiResult.isEmpty, "FFI result should not be empty")
        
        // Note: CLI mode test would require workbench-cli to be built
        // We'll skip that for now since we're focusing on FFI integration
    }
}
