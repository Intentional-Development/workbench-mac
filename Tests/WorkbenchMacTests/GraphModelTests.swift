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

    func testDecodeFireflyGraph() throws {
        let url = teamRoot()
            .appendingPathComponent("firefly-iii-idl/intent/extracted/graph.json")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path),
                          "firefly graph not present")

        let result = loadGraph(at: url)
        switch result {
        case .failure(let e):
            XCTFail("decode failed: \(e)")
        case .success(let g):
            XCTAssertGreaterThanOrEqual(g.nodes.count, 300,
                "expected ≥ 300 nodes; got \(g.nodes.count)")
            XCTAssertFalse(g.edges.isEmpty)
        }
    }

    func testForceDirectedLayoutProducesAllPositions() throws {
        let json = """
        {
          "nodes": [
            {"id":"a","kind":"intent","state":"accepted"},
            {"id":"b","kind":"entity","state":"proposed"},
            {"id":"c","kind":"api","state":"inferred"}
          ],
          "edges": [
            {"from":"a","to":"b","kind":"realizes"},
            {"from":"b","to":"c","kind":"emits"}
          ]
        }
        """.data(using: .utf8)!
        let g = try JSONDecoder().decode(Graph.self, from: json)
        let positions = ForceDirectedLayout.compute(graph: g, size: CGSize(width: 800, height: 600), iterations: 50)
        XCTAssertEqual(positions.count, 3)
        for n in g.nodes {
            XCTAssertNotNil(positions[n.id])
        }
    }

    func testFireflyLayoutLatency() throws {
        let url = teamRoot()
            .appendingPathComponent("firefly-iii-idl/intent/extracted/graph.json")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path),
                          "firefly graph not present")
        let g = try JSONDecoder().decode(Graph.self, from: Data(contentsOf: url))
        let start = Date()
        let positions = ForceDirectedLayout.compute(graph: g, size: CGSize(width: 1400, height: 900), iterations: 120)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertEqual(positions.count, g.nodes.count)
        XCTAssertLessThan(elapsed, 2.0, "force-directed layout took \(elapsed)s — over 2s budget")
        print("force-directed layout firefly: \(g.nodes.count) nodes / \(g.edges.count) edges in \(String(format: "%.3f", elapsed))s")
    }
}
