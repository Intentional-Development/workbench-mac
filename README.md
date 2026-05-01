# Workbench Mac

Native macOS application for the Intentional Development Language (IDL) project.

## Overview

Workbench Mac is a SwiftUI-based macOS application (minimum macOS 14.0 Sonoma) providing:

- **IDL Editor**: Syntax-highlighted editor for `.idl` files using Runestone
- **Extract**: Brownfield extraction from existing codebases (Dart, PHP, TypeScript, etc.)
- **Emit**: Code generation to multiple targets (Node.js, Go, Python, Rust)
- **Drift**: Parity matrix analysis between IDL spec and implementation

## Architecture

```
Sources/
├── WorkbenchApp.swift      # @main App entry
├── Views/
│   ├── EditorView.swift    # IDL editor with Runestone
│   ├── ExtractView.swift   # Brownfield extraction UI
│   ├── EmitView.swift      # Code generation UI
│   └── DriftView.swift     # Drift analysis UI
├── Models/
│   └── IDLModels.swift     # Codable structs mirroring IDL AST
└── Services/
    ├── IDLCore.swift       # Bridge to idl-core (temporary shell-out to TS CLI)
    └── FileService.swift   # File I/O with security-scoped resources
```

## Current Status: Bootstrap (Wave 7)

**Temporary Bridge**: Currently shells out to `workbench-cli` (TypeScript) for all IDL operations. This is a stopgap until Stark's Rust `idl-core` FFI lands via swift-bridge.

**FFI Migration Path**: See `docs/RUST_BRIDGE_PLAN.md` for the planned transition to native Rust FFI.

## Build Requirements

- macOS 14.0+ (Sonoma)
- Xcode 15.0+ / Swift 5.9+
- `workbench-cli` installed at `../workbench-cli/` (for current bridge)

## Building

```bash
swift build
swift run
```

Or open in Xcode:
```bash
open Package.swift
```

**Dependencies**

None (native SwiftUI and AppKit only for bootstrap)

Future:
- Custom editor library or LSP client for syntax highlighting
- swift-bridge FFI bindings (once idl-core lands)

## Roadmap

- [ ] Integrate Rust FFI bindings (swift-bridge) once `idl-rs/idl-ffi/` lands
- [ ] Custom IDL TextMate grammar for Runestone
- [ ] Graph visualization (React Flow equivalent in SwiftUI)
- [ ] State machine diagram rendering
- [ ] Capability map view
- [ ] Multi-document tabs
- [ ] App Sandbox compliance
- [ ] Notarization for distribution

## License

See parent project LICENSE.

## Team

Wave 7 bootstrap: Banner (Frontend/Extraction Specialist)
