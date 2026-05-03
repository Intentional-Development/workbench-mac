# Workbench Mac

Native macOS SwiftUI application for IDL (Intentional Development Language).

**Current Version:** v0.9.9-rc.4  
**Schema:** v0.1.9  
**Status:** Release candidate, feature parity with IDL v0.9.9 stack

---

## Architecture

```
┌─────────────────────────────┐
│ SwiftUI Views               │
│ (Editor, Graph, Drift, etc) │
└─────────────┬───────────────┘
              │
┌─────────────▼───────────────┐
│ IDLCore Service (Swift)     │
│ - FFI calls (parse_graph)   │   ← W25: Native Rust FFI
│ - CLI bridge (extract/emit) │   ← W24: workbench-cli shell-out
└─────────────┬───────────────┘
              │
    ┌─────────▼─────────┐
    │                   │
┌───▼────┐      ┌───────▼──────┐
│ idl-ffi│      │ workbench-cli│
│ (Rust) │      │  (Node/TS)   │
└────────┘      └──────────────┘
```

---

## Building with Rust FFI (W25+)

Workbench Mac uses the `idl-ffi` Rust crate for fast IDL graph parsing.

### Prerequisites

- **Swift 5.9+** (included with Xcode 15+)
- **Rust 1.70+**: 
  ```bash
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  ```

### Build Steps

1. **Build the FFI library:**
   ```bash
   cd ../idl-rs
   cargo build --release -p idl-ffi
   ```
   This produces:
   - `target/release/libidl_ffi.a` (17MB static lib)
   - `target/release/libidl_ffi.dylib` (694KB dynamic lib)

2. **Build workbench-mac:**
   ```bash
   cd ../workbench-mac
   swift build
   ```

3. **Run tests:**
   ```bash
   swift test
   ```
   Expected: 35+ tests pass (33 existing + 3 FFI tests)

### Fallback to CLI Mode

If the FFI build fails or you want to use the Node.js bridge:

```bash
IDL_USE_CLI=1 swift run WorkbenchMac
```

This forces shell-out to `workbench-cli` for all operations (slower, but works without Rust).

### What Uses FFI vs CLI (W25)

| Operation | Mode | Notes |
|-----------|------|-------|
| `parse_graph` | **FFI** | ~100x faster than CLI spawn |
| `extract` | CLI | Heavy operation, shells out |
| `emit` | CLI | Codegen, shells out |
| `drift` | CLI | Complex, uses language-specific tools |
| `validate` | CLI | Lightweight, FFI not yet wired |
| `classify` | CLI | Behavior analysis, FFI deferred to W26 |

---

## Overview

Workbench Mac provides:

- **IDL Editor**: Syntax-highlighted editor for `.idl` files
- **MCP Integration**: Connected to idl-mcp-server for proposals and mutations
- **Behavior Classification**: 6-role DDD taxonomy viewer
- **Perspectives**: 9-role stakeholder views (PM, frontend, backend, etc)
- **Derived Prompts**: Generate IDE-specific prompts (Cursor, Copilot, Claude)
- **Proposal Review**: Full CRUD on IDL proposals with audit trail
- **Extract**: Brownfield extraction from existing codebases
- **Emit**: Code generation to multiple targets
- **Drift**: Parity matrix analysis between IDL spec and implementation
- **Graph Canvas**: Force-directed layout visualization

---

## Directory Structure

```
Sources/
├── WorkbenchApp.swift       # @main App entry
├── Views/
│   ├── EditorView.swift     # IDL editor
│   ├── ExtractView.swift    # Brownfield extraction UI
│   ├── EmitView.swift       # Code generation UI
│   ├── DriftView.swift      # Drift analysis UI
│   ├── GraphView.swift      # Graph visualization
│   ├── BehaviorView.swift   # Behavior classification (W23)
│   ├── PerspectivesView.swift # Stakeholder views (W23)
│   ├── DerivedPromptsView.swift # Prompt generation (W24)
│   └── ProposalReviewView.swift # Proposal CRUD (W24)
├── Models/
│   ├── IDLModels.swift      # Codable structs mirroring IDL AST
│   ├── BehaviorModel.swift  # Behavior classification models
│   ├── ProposalModel.swift  # Proposal data structures
│   └── GraphModel.swift     # Graph node/edge models
└── Services/
    ├── IDLCore.swift        # FFI + CLI bridge
    ├── MCPClient.swift      # MCP JSON-RPC over stdio
    └── FileService.swift    # File I/O with security-scoped resources
```

---

## Roadmap

**W25 (Current):**
- ✅ Rust FFI for `parse_graph` (raw C FFI chosen over swift-bridge)
- ✅ Feature flag for CLI fallback (`IDL_USE_CLI`)
- ✅ FFI integration tests

**W26 (Next):**
- [ ] Extend FFI to `validate_graph` and `classify_behavior`
- [ ] Performance tuning (measure FFI vs CLI overhead)
- [ ] Incremental parsing support

**Post-v1.0:**
- [ ] LSP integration for editor
- [ ] Real-time collaboration features
- [ ] Custom IDL TextMate grammar
- [ ] App Sandbox compliance + notarization

---

## License

See parent project LICENSE.

---

## Team

- **Parker** (Frontend Dev): SwiftUI views, FFI integration
- **Stark** (Architect): idl-ffi crate, FFI surface
- **Banner** (Backend Dev): MCP client, services layer
- **Romanoff** (DevRel): Documentation, roadmap
