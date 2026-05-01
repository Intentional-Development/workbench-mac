import XCTest
@testable import WorkbenchMac

final class GraphModelTests: XCTestCase {

    /// Locate the team root from the test working directory.
    private func teamRoot() -> URL {
        // Tests run from workbench-mac/ as cwd; team root is parent.
        let candidates = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .deletingLastPathComponent(),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
            URL(fileURLWithPath: "/Users/carloshm/personal-projects/intentional"),
        ]
        for c in candidates {
            if FileManager.default.fileExists(
                atPath: c.appendingPathComponent("realworld-idl/intent/extracted/realworld-graph.json").path
            ) {
                return c
            }
        }
        return candidates[0]
    }

    func testDecodeRealworldGraph() throws {
        let url = teamRoot()
            .appendingPathComponent("realworld-idl/intent/extracted/realworld-graph.json")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path),
                          "realworld demo graph not present")

        let result = loadGraph(at: url)
        switch result {
        case .failure(let e):
            XCTFail("decode failed: \(e)")
        case .success(let g):
            XCTAssertGreaterThanOrEqual(g.nodes.count, 85,
                "expected ≥ 85 nodes; got \(g.nodes.count)")
            XCTAssertFalse(g.edges.isEmpty)
            // Spot-check kernel kind diversity & state coverage.
            let kinds = Set(g.nodes.map { $0.kind.rawValue })
            XCTAssertTrue(kinds.contains("intent"))
            XCTAssertTrue(kinds.contains("api"))
        }
    }

    func testUnknownKindIsPermissive() throws {
        let json = """
        {
          "version": "0.1.0",
          "nodes": [
            {"id":"x:1","kind":"made_up_block","state":"proposed"}
          ],
          "edges": []
        }
        """.data(using: .utf8)!
        let g = try JSONDecoder().decode(Graph.self, from: json)
        XCTAssertEqual(g.nodes.count, 1)
        if case .unknown(let s) = g.nodes[0].kind {
            XCTAssertEqual(s, "made_up_block")
        } else {
            XCTFail("expected .unknown for non-kernel kind")
        }
    }

    func testUnknownEdgeKindIsPermissive() throws {
        let json = """
        {
          "nodes": [],
          "edges": [
            {"from":"a","to":"b","kind":"future_relation"}
          ]
        }
        """.data(using: .utf8)!
        let g = try JSONDecoder().decode(Graph.self, from: json)
        XCTAssertEqual(g.edges.count, 1)
        if case .unknown(let s) = g.edges[0].kind {
            XCTAssertEqual(s, "future_relation")
        } else {
            XCTFail("expected .unknown edge kind")
        }
    }
}
