# Changelog

All notable changes to workbench-mac will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- (Placeholder for in-progress work)

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
