# Rust FFI Bridge Plan

## Overview

This document outlines the migration path from the current TypeScript CLI shell-out approach to native Rust FFI via the `idl-core` crate.

## Current State (Wave 7 Bootstrap)

**Bridge Mechanism**: Shell-out to Node.js CLI
- Location: `Services/IDLCore.swift`
- Method: `Process` with `/usr/bin/env node ../workbench-cli/dist/index.js`
- Operations:
  - `extract --source <path> --output -` → brownfield extraction
  - `emit --idl <path> --target <lang> --output <path>` → code generation
  - `drift --idl <path> --code <path>` → parity analysis
  - `parse --file <path> --format json` → IDL parsing to AST

**Limitations**:
- Spawns Node.js process per operation (slow)
- No streaming or progress callbacks
- Error messages pass through shell stdout/stderr
- Cannot leverage Rust's performance or safety

## Target State: Native FFI

**Rust Side** (`idl-rs/idl-core/`):
- Parser: `idl_core_parse(content: &str) -> Result<IDLDocument>`
- Extractor: `idl_core_extract(source_path: &str, language: Language) -> Result<String>`
- Emitter: `idl_core_emit(ast: &IDLDocument, target: Target, output: &str) -> Result<()>`
- Drift: `idl_core_drift(idl: &IDLDocument, code_path: &str) -> Result<DriftReport>`

**Swift Side** (`Sources/Services/IDLCore.swift`):
- Import generated swift-bridge bindings
- Replace `runCLI()` with direct FFI calls
- Handle Rust `Result<T, E>` → Swift `throws`
- Marshal strings and structs across boundary

## FFI Mechanism Recommendation

### Option A: swift-bridge ✅ RECOMMENDED

**Pros**:
- Modern, actively maintained
- Excellent ergonomics for bidirectional Swift ↔ Rust
- Automatic binding generation from Rust annotations
- Supports structs, enums, error types, async
- Good performance (zero-copy where possible)

**Cons**:
- Requires Rust nightly for some features
- Build system integration (needs build.rs)
- Documentation still maturing

**Example**:
```rust
#[swift_bridge::bridge]
mod ffi {
    extern "Rust" {
        type IDLCore;
        fn idl_core_parse(content: &str) -> Result<String, String>;
    }
}
```

Swift:
```swift
import idl_core_ffi

let result = idl_core_parse(content)
```

### Option B: UniFFI

**Pros**:
- Mozilla-backed, stable
- Great for mobile (iOS/Android)
- UDL-based interface definition

**Cons**:
- Heavier runtime overhead
- Designed for mobile, less optimized for macOS desktop
- Less ergonomic than swift-bridge for pure Swift targets

### Option C: Raw C ABI (cbindgen)

**Pros**:
- Maximum compatibility
- Full control

**Cons**:
- Manual marshalling
- Verbose, error-prone
- No automatic Rust error handling → Swift throws

**Decision**: Use **swift-bridge** for ergonomics and performance.

## Migration Path

### Phase 1: Parallel FFI (No Behavior Change)
1. Stark implements FFI exports in `idl-rs/idl-core/src/ffi.rs`
2. Add `swift-bridge-build` to `idl-core/build.rs`
3. Generate bindings: `cargo build` → `idl-core-ffi.swift`
4. Add generated bindings to Workbench Mac via SPM or XCFramework
5. Keep TS CLI shell-out as fallback (runtime feature flag)

### Phase 2: Replace Shell-out
1. Update `IDLCore.swift`:
   - `extractIDL()` → `idl_core_extract()`
   - `emitCode()` → `idl_core_emit()`
   - `analyzeDrift()` → `idl_core_drift()`
   - `parseIDL()` → `idl_core_parse()`
2. Remove `Process` code
3. Test parity with existing CLI behavior

### Phase 3: Advanced Features
- Streaming progress via Rust channels → Swift AsyncStream
- In-memory AST manipulation (no temp files)
- Incremental parsing for editor responsiveness
- Multi-threaded extraction (Rust rayon → Swift actors)

## Service-by-Service FFI Mapping

| Swift Service | Rust FFI Function | Priority |
|---------------|-------------------|----------|
| `IDLCore.parseIDL()` | `idl_core_parse()` | P0 (editor) |
| `IDLCore.analyzeDrift()` | `idl_core_drift()` | P0 (drift tab) |
| `IDLCore.extractIDL()` | `idl_core_extract()` | P1 (extraction) |
| `IDLCore.emitCode()` | `idl_core_emit()` | P1 (codegen) |

**Parser and drift engine first** — these are hot-path operations for the editor and analysis UI.

## Build Integration

### Option 1: XCFramework (Recommended for Distribution)
1. Build `idl-core` as static lib for `aarch64-apple-darwin` and `x86_64-apple-darwin`
2. Package as XCFramework with swift-bridge headers
3. Add to Workbench Mac SPM dependencies

### Option 2: Direct SPM Integration
1. Add `idl-core` as SPM system library target
2. Run `cargo build --release` as pre-build step
3. Link against `.dylib` or `.a`

## Open Questions for Carlos

1. **Static vs Dynamic Linking**: Prefer `.a` (static) for App Store distribution, or `.dylib` (dynamic) for development speed?
2. **Target Architectures**: Support Intel Macs (x86_64) or Apple Silicon only (aarch64)?
3. **Rust Toolchain**: Require developers to install Rust, or bundle pre-built binaries?
4. **Fallback Strategy**: Keep TS CLI as runtime fallback for FFI failures, or hard cut-over?

## Timeline Estimate

- **Phase 1** (Parallel FFI): 1 week (Stark rust-side, Banner swift-side)
- **Phase 2** (Replace shell-out): 3 days (Banner)
- **Phase 3** (Advanced features): 2 weeks (Banner + Stark)

**Total**: ~3 weeks to production-ready FFI, assuming Stark's `idl-core` crate is API-stable.

## References

- swift-bridge: https://github.com/chinedufn/swift-bridge
- UniFFI: https://mozilla.github.io/uniffi-rs/
- Stark's FFI plan: `idl-rs/idl-ffi/SWIFT_BRIDGE_PLAN.md` (pending)
