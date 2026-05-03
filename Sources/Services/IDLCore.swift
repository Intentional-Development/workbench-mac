import Foundation

// C FFI declarations for idl-ffi Rust library
@_silgen_name("idl_parse_graph")
private func idl_parse_graph(_ path: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>?

@_silgen_name("idl_free_string")
private func idl_free_string(_ ptr: UnsafeMutablePointer<CChar>?)

enum IDLCoreError: Error {
    case cliNotFound
    case executionFailed(String)
    case invalidOutput
    case ffiError(String)
}

actor IDLCore {
    static let shared = IDLCore()
    
    private let cliPath: String
    private let useFFI: Bool
    
    private init() {
        // Default path to workbench-cli - can be configured via environment or settings
        let projectRoot = "/Users/carloshm/personal-projects/intentional"
        self.cliPath = "\(projectRoot)/workbench-cli/dist/index.js"
        
        // Feature flag: use FFI by default, fall back to CLI if IDL_USE_CLI=1
        self.useFFI = ProcessInfo.processInfo.environment["IDL_USE_CLI"] != "1"
    }
    
    // MARK: - Extraction
    
    func extractIDL(from sourcePath: String) async throws -> String {
        let args = ["extract", "--source", sourcePath, "--output", "-"]
        let output = try await runCLI(args: args)
        return output
    }
    
    // MARK: - Code Generation (Emit)
    
    func emitCode(idlPath: String, target: String, outputPath: String) async throws -> String {
        let args = ["emit", "--idl", idlPath, "--target", target, "--output", outputPath]
        let output = try await runCLI(args: args)
        return output
    }
    
    // MARK: - Drift Analysis
    
    func analyzeDrift(idlPath: String, codePath: String) async throws -> String {
        let args = ["drift", "--idl", idlPath, "--code", codePath]
        let output = try await runCLI(args: args)
        return output
    }
    
    // MARK: - Parsing
    
    func parseGraph(path: String) async throws -> String {
        if useFFI {
            return try parseGraphViaFFI(path: path)
        } else {
            return try await parseGraphViaCLI(path: path)
        }
    }
    
    private func parseGraphViaFFI(path: String) throws -> String {
        guard let resultPtr = idl_parse_graph(path) else {
            throw IDLCoreError.ffiError("FFI returned null pointer")
        }
        defer { idl_free_string(resultPtr) }
        
        let json = String(cString: resultPtr)
        
        // Check for error JSON: {"error": "..."}
        if json.contains("\"error\""),
           let data = json.data(using: .utf8),
           let errorObj = try? JSONSerialization.jsonObject(with: data) as? [String: String],
           let errorMsg = errorObj["error"] {
            throw IDLCoreError.ffiError(errorMsg)
        }
        
        return json
    }
    
    private func parseGraphViaCLI(path: String) async throws -> String {
        let args = ["parse", "--path", path, "--format", "json"]
        return try await runCLI(args: args)
    }
    
    func parseIDL(content: String) async throws -> IDLDocument {
        // For now, write to temp file and parse
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("temp-\(UUID().uuidString).idl")
        
        try content.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }
        
        let args = ["parse", "--file", tempFile.path, "--format", "json"]
        let output = try await runCLI(args: args)
        
        // Parse JSON output to IDLDocument
        guard let data = output.data(using: .utf8) else {
            throw IDLCoreError.invalidOutput
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(IDLDocument.self, from: data)
    }
    
    // MARK: - Private Helpers
    
    private func runCLI(args: [String]) async throws -> String {
        // Verify CLI exists
        guard FileManager.default.fileExists(atPath: cliPath) else {
            throw IDLCoreError.cliNotFound
        }
        
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["node", cliPath] + args
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        if process.terminationStatus != 0 {
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw IDLCoreError.executionFailed(errorMessage)
        }
        
        return String(data: outputData, encoding: .utf8) ?? ""
    }
}

// MARK: - FFI Integration Status (W25)
// ✅ parse_graph: FFI-native (toggleable via IDL_USE_CLI env var)
// ❌ extract, emit, drift: Still shell out to workbench-cli (heavier operations, deferred to W26)
// Feature flag: Set IDL_USE_CLI=1 to force CLI mode for all operations
