import Foundation

enum IDLCoreError: Error {
    case cliNotFound
    case executionFailed(String)
    case invalidOutput
}

actor IDLCore {
    static let shared = IDLCore()
    
    private let cliPath: String
    
    private init() {
        // Default path to workbench-cli - can be configured via environment or settings
        let projectRoot = "/Users/carloshm/personal-projects/intentional"
        self.cliPath = "\(projectRoot)/workbench-cli/dist/index.js"
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

// MARK: - Future FFI Bridge Point
// When Rust idl-core FFI is ready via swift-bridge:
// - Replace runCLI() with direct FFI calls to idl_core_extract(), idl_core_emit(), etc.
// - Remove Process/shell-out code
// - Import swift-bridge generated bindings
// - See docs/RUST_BRIDGE_PLAN.md for migration path
