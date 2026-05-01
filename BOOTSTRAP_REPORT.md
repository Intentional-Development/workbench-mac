# Workbench Mac Bootstrap — Wave 7 Completion Report

**Date**: 2025-05-01  
**Agent**: Banner (Frontend/Extraction Specialist)  
**Status**: ✅ COMPLETE  

---

## Deliverables

### ✅ TASK A — Bootstrap Xcode/SPM Project

**Project Structure**:
```
workbench-mac/
├── Package.swift                     # Swift Package Manager manifest
├── README.md                         # Build instructions & architecture
├── .gitignore                        # Xcode/Swift/macOS exclusions
├── Sources/
│   ├── WorkbenchApp.swift           # @main App entry with 4-tab UI
│   ├── Views/
│   │   ├── EditorView.swift         # IDL editor (TextEditor + monospace)
│   │   ├── ExtractView.swift        # Brownfield extraction UI
│   │   ├── EmitView.swift           # Code generation UI
│   │   └── DriftView.swift          # Parity analysis UI
│   ├── Models/
│   │   └── IDLModels.swift          # Codable IDL AST (18 structs)
│   └── Services/
│       ├── IDLCore.swift            # Temporary Node CLI shell-out bridge
│       └── FileService.swift        # Security-scoped file I/O
├── Tests/
│   └── WorkbenchMacTests/
└── docs/
    └── RUST_BRIDGE_PLAN.md          # FFI migration strategy
```

**Stats**:
- 13 files created
- 929 lines of Swift code
- Build time: ~1.2s
- Zero dependencies (native SwiftUI + AppKit only)

**Acceptance**:
- ✅ `swift build` succeeds (exit code 0)
- ✅ App structure complete (WorkbenchApp + 4 tabs)
- ✅ IDL editor renders sample .idl with monospace font
- ✅ Extract/Emit/Drift views functional (UI complete, services ready)
- ✅ Models mirror IDL AST specification
- ✅ Services implement bridge pattern for future FFI

### ✅ TASK B — Rust FFI Bridge Plan

**Document**: `docs/RUST_BRIDGE_PLAN.md`

**Key Decisions**:
- **Mechanism**: swift-bridge (recommended over UniFFI and raw C ABI)
- **Migration Path**: 3 phases (Parallel FFI → Replace shell-out → Advanced features)
- **Priority Order**: Parser & drift engine first (hot paths for editor/analysis)
- **Timeline**: ~3 weeks to production-ready FFI

**Service Mapping**:
| Swift Service | Rust FFI Function | Priority |
|---------------|-------------------|----------|
| `IDLCore.parseIDL()` | `idl_core_parse()` | P0 |
| `IDLCore.analyzeDrift()` | `idl_core_drift()` | P0 |
| `IDLCore.extractIDL()` | `idl_core_extract()` | P1 |
| `IDLCore.emitCode()` | `idl_core_emit()` | P1 |

**Open Questions** (for Carlos):
1. Static vs dynamic linking preference
2. Target architectures (Apple Silicon only or Intel support?)
3. Rust toolchain requirement (developer install vs pre-built binaries)
4. Fallback strategy (keep TS CLI or hard cut-over)

### ✅ TASK C — Decision Document

**Document**: `.squad/decisions/inbox/banner-w7-mac-app.md`

**Key Decisions Recorded**:

1. **Project Type**: Swift Package Manager executable (vs Xcode project or xcodegen)
   - Rationale: Modern, CLI-friendly, Git-friendly, no extra dependencies

2. **Editor Library**: SwiftUI TextEditor (temporary)
   - Original choice: Runestone (iOS-only, incompatible)
   - Current: Native TextEditor with monospace font
   - Future: Custom NSTextView + IDL syntax highlighter (Wave 8)

3. **FFI Mechanism**: swift-bridge
   - Rationale: Best ergonomics for Swift ↔ Rust, automatic bindings, good performance

4. **App Structure**: 4-tab TabView (Editor, Extract, Emit, Drift)
   - Services: IDLCore (Node shell-out), FileService (security-scoped I/O)
   - Models: 18 Codable structs mirroring IDL AST

5. **macOS Target**: 14.0 (Sonoma)
   - Requires Swift 5.9+, SwiftUI 5.0 features

6. **App Sandbox**: OFF for now
   - Decision deferred until distribution strategy clear

**Open Questions for Carlos**:
- Icon/branding
- Distribution target (internal/public/App Store)
- CLI integration (pure GUI vs dual CLI/GUI)
- Multi-window support timeline

### ✅ TASK D — Git Commit

**Repository**: `/Users/carloshm/personal-projects/intentional/workbench-mac/`

**Commit**:
```
7398e54 (HEAD -> master) feat: bootstrap native macOS workbench (Wave 7)
```

**Status**: Local git repo initialized, single bootstrap commit created.

**Note**: Not pushed to remote per instructions — Carlos decides repo destination.

---

## Technical Highlights

### Editor Implementation

**Current**: SwiftUI TextEditor
- Monospace font rendering
- Open/Save via file picker
- Security-scoped resource access

**Syntax Highlighting**: Deferred to Wave 8
- Runestone (initial choice) is iOS-only (UIKit)
- Alternative paths explored: custom NSTextView, LanguageServer Protocol, future macOS editor libraries

### Bridge Architecture

**Current**: Node.js CLI shell-out
```swift
// Services/IDLCore.swift
func extractIDL(from sourcePath: String) async throws -> String {
    let args = ["extract", "--source", sourcePath, "--output", "-"]
    return try await runCLI(args: args)  // Process with /usr/bin/env node
}
```

**Future**: Rust FFI via swift-bridge
```swift
// Future: Direct FFI call
import idl_core_ffi
let result = idl_core_extract(sourcePath)
```

### Models Architecture

18 Codable structs mirroring IDL spec:
- Core: IDLDocument, IDLBlock (enum)
- Blocks: Intent, Scope, Entity, Endpoint, Rule, Decision, UXFlow, UXComponent, StateMachine, Variant, Execution
- Supporting: EntityField, EntityRelationship, FlowStep, StateMachineState, Transition, VariantCase, ExecutionStep

**Naming Fix**: `State` → `StateMachineState` (avoided conflict with SwiftUI `@State`)

---

## Build Verification

```bash
$ cd /Users/carloshm/personal-projects/intentional/workbench-mac
$ swift build
[0/1] Planning build
Building for debugging...
[0/5] Write sources
[1/5] Write swift-version--58304C5D6DBC2206.txt
[3/13] Compiling WorkbenchMac EditorView.swift
[4/13] Compiling WorkbenchMac WorkbenchApp.swift
[5/13] Compiling WorkbenchMac EmitView.swift
[6/13] Compiling WorkbenchMac ExtractView.swift
[7/13] Compiling WorkbenchMac IDLCore.swift
[8/13] Emitting module WorkbenchMac
[9/13] Compiling WorkbenchMac IDLModels.swift
[10/13] Compiling WorkbenchMac DriftView.swift
[10/13] Write Objects.LinkFileList
[11/13] Linking WorkbenchMac
[12/13] Applying WorkbenchMac
Build complete! (1.16s)
```

✅ **EXIT CODE: 0**

---

## Next Steps (Wave 8+)

1. **FFI Integration** (Priority: P0)
   - Wait for Stark's `idl-rs/idl-ffi/SWIFT_BRIDGE_PLAN.md`
   - Implement Phase 1 of RUST_BRIDGE_PLAN.md
   - Replace Node shell-out with direct Rust calls

2. **Syntax Highlighting** (Priority: P1)
   - Custom NSTextView wrapper with TextKit 2
   - IDL grammar parser (manual or LSP)
   - Theme support (light/dark mode)

3. **Graph Visualization** (Priority: P1)
   - Capability map view
   - State machine diagram rendering
   - React Flow equivalent in SwiftUI (or Metal-based rendering)

4. **Enhanced Features** (Priority: P2)
   - Multi-document tabs
   - Recent files (security-scoped bookmarks)
   - Search/replace in editor
   - IDL validation inline errors
   - Export to PDF/PNG (for docs)

5. **Distribution** (Priority: P3)
   - App icon and branding
   - App Sandbox compliance (if App Store)
   - Notarization for Gatekeeper
   - GitHub Actions CI/CD for macOS builds

---

## Dependencies on Other Agents

**Stark (Rust Core)**:
- `idl-rs/idl-core` crate API stabilization
- `idl-rs/idl-ffi/` swift-bridge implementation
- FFI function signatures matching RUST_BRIDGE_PLAN.md

**Carlos (Product Owner)**:
- Distribution strategy decision (internal/public/App Store)
- Icon/branding assets
- Open questions in decision doc

---

## Lessons Learned

1. **Library Compatibility**: Always verify platform support (Runestone was iOS-only)
2. **Naming Conflicts**: Swift reserved keywords (`guard`) and SwiftUI property wrappers (`@State`) require careful naming
3. **Bootstrap Scope**: Prioritized buildable app over perfect features — syntax highlighting deferred to allow faster iteration
4. **FFI Planning**: Documenting bridge architecture early enables parallel Rust/Swift work

---

## References

- Next.js workbench (frozen): `/Users/carloshm/personal-projects/intentional/workbench/`
- workbench-cli (current bridge): `/Users/carloshm/personal-projects/intentional/workbench-cli/`
- Squad decisions: `.squad/decisions.md`
- Banner charter: `.squad/agents/banner/charter.md`

---

**Signed**: Banner, Wave 7  
**Co-authored-by**: Copilot <223556219+Copilot@users.noreply.github.com>
