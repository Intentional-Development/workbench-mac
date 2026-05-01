import XCTest
@testable import WorkbenchMac

// MARK: - Fixture JSON (sampled from Wave 10 realworld drift output)

private let fixtureWrappedJSON = """
{
  "graph_path": "realworld-idl/intent/extracted/realworld-graph.json",
  "source_root": "realworld=realworld",
  "entries": [
    {
      "node_id": "intent:realworld-blog",
      "node_kind": "intent",
      "verdict": "aligned",
      "uri": "repo://realworld/node-express-realworld-example-app/src/app/routes/routes.ts",
      "resolved_path": "realworld/node-express-realworld-example-app/src/app/routes/routes.ts",
      "note": null
    },
    {
      "node_id": "entity:user",
      "node_kind": "entity",
      "verdict": "aligned",
      "uri": "repo://realworld/node-express-realworld-example-app/src/prisma/schema.prisma",
      "resolved_path": "realworld/node-express-realworld-example-app/src/prisma/schema.prisma",
      "note": null
    },
    {
      "node_id": "api:POST-/api/users/login",
      "node_kind": "api",
      "verdict": "shifted",
      "uri": "repo://realworld/node-express-realworld-example-app/src/app/routes/auth/auth.ts",
      "resolved_path": null,
      "note": "handler signature changed"
    },
    {
      "node_id": "rule:password-hashing",
      "node_kind": "rule",
      "verdict": "missing",
      "uri": null,
      "resolved_path": null,
      "note": "no corresponding implementation found"
    },
    {
      "node_id": "api:GET-/api/healthz",
      "node_kind": "api",
      "verdict": "new-in-code",
      "uri": "repo://realworld/node-express-realworld-example-app/src/app/routes/health.ts",
      "resolved_path": "realworld/node-express-realworld-example-app/src/app/routes/health.ts",
      "note": null
    }
  ]
}
"""

private let fixtureBareArrayJSON = """
[
  {
    "node_id": "intent:bare",
    "node_kind": "intent",
    "verdict": "aligned",
    "uri": "repo://x/src/main.ts",
    "resolved_path": null,
    "note": null
  },
  {
    "node_id": "entity:bare-missing",
    "node_kind": "entity",
    "verdict": "missing",
    "uri": null,
    "resolved_path": null,
    "note": null
  }
]
"""

final class DriftDashboardModelTests: XCTestCase {

    // MARK: - Parse wrapped format (standard W10 output)

    func testParseWrappedJSON() throws {
        let data = Data(fixtureWrappedJSON.utf8)
        let entries = try DriftSweepService.parse(data: data)

        XCTAssertEqual(entries.count, 5)
    }

    func testVerdictCounts() throws {
        let data = Data(fixtureWrappedJSON.utf8)
        let entries = try DriftSweepService.parse(data: data)

        let aligned   = entries.filter { $0.verdict == "aligned" }.count
        let shifted   = entries.filter { $0.verdict == "shifted" }.count
        let missing   = entries.filter { $0.verdict == "missing" }.count
        let newInCode = entries.filter { $0.verdict == "new-in-code" }.count

        XCTAssertEqual(aligned,   2)
        XCTAssertEqual(shifted,   1)
        XCTAssertEqual(missing,   1)
        XCTAssertEqual(newInCode, 1)
    }

    func testNodeIdAndKindPreserved() throws {
        let data = Data(fixtureWrappedJSON.utf8)
        let entries = try DriftSweepService.parse(data: data)

        let first = try XCTUnwrap(entries.first)
        XCTAssertEqual(first.node_id,   "intent:realworld-blog")
        XCTAssertEqual(first.node_kind, "intent")
        XCTAssertEqual(first.verdict,   "aligned")
        XCTAssertEqual(first.uri, "repo://realworld/node-express-realworld-example-app/src/app/routes/routes.ts")
    }

    func testOptionalFieldsAllowNull() throws {
        let data = Data(fixtureWrappedJSON.utf8)
        let entries = try DriftSweepService.parse(data: data)

        let missing = try XCTUnwrap(entries.first { $0.verdict == "missing" })
        XCTAssertNil(missing.uri)
        XCTAssertNil(missing.resolved_path)
        XCTAssertNotNil(missing.note)  // "no corresponding implementation found"
    }

    // MARK: - Parse bare-array format (fallback)

    func testParseBareArrayJSON() throws {
        let data = Data(fixtureBareArrayJSON.utf8)
        let entries = try DriftSweepService.parse(data: data)

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].node_id, "intent:bare")
        XCTAssertEqual(entries[1].verdict, "missing")
    }

    // MARK: - Corpus configuration

    func testAllCorporaHaveNonEmptyGraphPath() {
        for corpus in DriftCorpus.allCases {
            XCTAssertFalse(corpus.graphPath.isEmpty, "\(corpus.rawValue) has empty graphPath")
            XCTAssertFalse(corpus.sourceArg.isEmpty, "\(corpus.rawValue) has empty sourceArg")
        }
    }

    func testSourceArgContainsEquals() {
        for corpus in DriftCorpus.allCases {
            XCTAssertTrue(corpus.sourceArg.contains("="),
                          "\(corpus.rawValue) sourceArg missing '=': \(corpus.sourceArg)")
        }
    }

    // MARK: - DriftVerdict helpers

    func testAllVerdictsHaveLabels() {
        for v in DriftVerdict.allCases {
            XCTAssertFalse(v.label.isEmpty)
        }
    }

    func testVerdictRawValues() {
        XCTAssertEqual(DriftVerdict.aligned.rawValue,   "aligned")
        XCTAssertEqual(DriftVerdict.shifted.rawValue,   "shifted")
        XCTAssertEqual(DriftVerdict.missing.rawValue,   "missing")
        XCTAssertEqual(DriftVerdict.newInCode.rawValue, "new-in-code")
    }

    func testDriftEntryIdMatchesNodeId() throws {
        let data = Data(fixtureWrappedJSON.utf8)
        let entries = try DriftSweepService.parse(data: data)
        for entry in entries {
            XCTAssertEqual(entry.id, entry.node_id)
        }
    }
}
