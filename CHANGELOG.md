## [0.9.4] - 2025-01-20

### Wave 17 Results
- **TypeExpr DSL:** Prototype design complete, EBNF grammar covers all v0.1.6 kinds, round-trip lossless for type shape. Implementation path: `idl-rs/idl-typeexpr/` crate (W18+).
- **Paginated Validation:** Corpus-2 validated (141 schemas: 112 Stripe cursor-based + 29 firefly-iii page-based). Pagination warrants `kind: "paginated"` in v0.1.7 (W18).
- **Firefly-iii v0.1.6 Extraction:** Re-extracted with array-alias (24 schemas) + union (1 schema). DTO count 251 (24 NEW, not collapses). Conformance 99.6%/76.2% maintained. v0.1.6 extract/emit validated.
- **All W16 unresolved items CLOSED:** TypeExpr designed, pagination validated, firefly-iii extracted.


All notable changes to workbench-mac will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- (Placeholder for in-progress work)

## [0.9.3] - 2025-01-03

- **workbench-mac:** version alignment, no functional changes.

## [0.9.2] - 2026-05-02

### Changed
- Version alignment with IDL v0.9.2 (no functional changes)
- Schema compatibility: validated against v0.1.5

## [0.9.1] - 2026-05-02

### Changed
- Version alignment with IDL ecosystem (no functional changes this wave)

## [0.9.0] - 2026-05-02

### Added (Waves 10-13 Cumulative)
- Wave 13: Canonical-DTO gap closure across 4 corpora (n8n 93.8%, firefly-iii 76.2%, localsend 66.7% schema strict conformance)
- Wave 11: Drift Dashboard tab (Sources/Models, Services, Views) with alignment status visualization
- Wave 11: Drift Dashboard unit tests (swift test green)
- Wave 9: Graph canvas with force-directed layout (Wave 9)

### Changed
- Build status: `swift build` + `swift test` pass cleanly
- Dashboard supports 4 corpora drift JSON (realworld, n8n, firefly-iii, localsend)

### Fixed
- Wave 11: Force-directed layout positioning for large graphs (100+ nodes)

## [0.6.0-rc] - 2026-04-30

### Added
- Wave 8: Graph viewer with 3-zone layout (P2 starter)
- Wave 8: SwiftUI graph canvas with zoom/pan
- Wave 7: Bootstrap native macOS workbench (Wave 7)

---

[0.10.0]: https://github.com/Intentional-Development/workbench-mac/compare/v0.6.0-rc...v0.10.0
[0.6.0-rc]: https://github.com/Intentional-Development/workbench-mac/releases/tag/v0.6.0-rc
