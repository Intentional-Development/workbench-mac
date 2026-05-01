import Foundation

// MARK: - Drift Sweep Service
// Shells out to `idl drift code --json --source <arg> <graph>` from the workspace root.

enum DriftSweepError: Error, LocalizedError {
    case binaryNotFound(String)
    case sweepFailed(String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound(let p): return "idl binary not found at: \(p)"
        case .sweepFailed(let msg):  return "Sweep failed: \(msg)"
        case .parseError(let msg):   return "JSON parse error: \(msg)"
        }
    }
}

actor DriftSweepService {
    static let shared = DriftSweepService()

    private let workspaceRoot = "/Users/carloshm/personal-projects/intentional"
    private let idlBinaryPath = "/Users/carloshm/personal-projects/intentional/idl-rs/target/debug/idl"

    // In-memory cache keyed by corpus
    private var cache: [DriftCorpus: [DriftEntry]] = [:]

    func cachedEntries(for corpus: DriftCorpus) -> [DriftEntry]? {
        cache[corpus]
    }

    func runSweep(corpus: DriftCorpus) async throws -> [DriftEntry] {
        guard FileManager.default.fileExists(atPath: idlBinaryPath) else {
            throw DriftSweepError.binaryNotFound(idlBinaryPath)
        }

        let process = Process()
        let outputPipe = Pipe()
        let errorPipe  = Pipe()

        process.executableURL = URL(fileURLWithPath: idlBinaryPath)
        process.arguments = [
            "drift", "code",
            "--json",
            "--source", corpus.sourceArg,
            corpus.graphPath,
        ]
        process.currentDirectoryURL = URL(fileURLWithPath: workspaceRoot)
        process.standardOutput = outputPipe
        process.standardError  = errorPipe

        try process.run()
        process.waitUntilExit()

        let rawOut = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let rawErr = errorPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let msg = String(data: rawErr, encoding: .utf8) ?? "unknown error"
            throw DriftSweepError.sweepFailed(msg)
        }

        let entries = try Self.parse(data: rawOut)
        cache[corpus] = entries
        return entries
    }

    // MARK: - Parsing (static so tests can call it without the actor)

    static func parse(data: Data) throws -> [DriftEntry] {
        let decoder = JSONDecoder()
        // Try wrapped format first: { graph_path, source_root, entries }
        if let output = try? decoder.decode(DriftSweepOutput.self, from: data) {
            return output.entries
        }
        // Fallback: bare array
        if let entries = try? decoder.decode([DriftEntry].self, from: data) {
            return entries
        }
        throw DriftSweepError.parseError("Unrecognised JSON shape")
    }
}
