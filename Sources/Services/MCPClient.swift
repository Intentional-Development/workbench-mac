import Foundation

// MARK: - MCP Client (W21 idl-mcp-server bridge)
//
// stdio transport stub for spawning idl-mcp-server and calling:
// - 5 read tools: idl.read_file, idl.list_files, idl.get_node, idl.list_nodes, idl.query_graph
// - 5 proposal mutation tools: idl.proposal.* (listed but not invoked; mutations deferred to W24)
//
// Uses Foundation Process/Pipe for stdio transport.

public enum MCPError: Error, LocalizedError {
    case serverNotFound(String)
    case spawnFailed(String)
    case invalidResponse(String)
    case timeout
    case unsupportedTool(String)
    
    public var errorDescription: String? {
        switch self {
        case .serverNotFound(let path): return "MCP server not found at: \(path)"
        case .spawnFailed(let msg): return "Failed to spawn MCP server: \(msg)"
        case .invalidResponse(let msg): return "Invalid response: \(msg)"
        case .timeout: return "Request timed out"
        case .unsupportedTool(let name): return "Tool not supported: \(name)"
        }
    }
}

// MARK: - MCP Tool Descriptors

public struct MCPTool: Identifiable, Codable {
    public let id: String
    public let name: String
    public let description: String
    public let inputSchema: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case name, description, inputSchema
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.id = name
        self.description = try container.decode(String.self, forKey: .description)
        // inputSchema is complex JSON, skip for now
        self.inputSchema = nil
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
    }
    
    public init(name: String, description: String, inputSchema: [String: Any]? = nil) {
        self.id = name
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

public enum MCPToolCategory: String, CaseIterable {
    case read = "Read Tools"
    case proposal = "Proposal Tools"
    case mutation = "Mutation Tools"
    
    var tools: [String] {
        switch self {
        case .read:
            return [
                "idl.read_file",
                "idl.list_files",
                "idl.get_node",
                "idl.list_nodes",
                "idl.query_graph"
            ]
        case .proposal:
            return [
                "idl.proposal.add_node",
                "idl.proposal.update_node",
                "idl.proposal.remove_node",
                "idl.proposal.add_edge",
                "idl.proposal.remove_edge"
            ]
        case .mutation:
            return []  // Future expansion
        }
    }
}

// MARK: - MCP Client

@MainActor
public final class MCPClient: ObservableObject {
    @Published public var isConnected: Bool = false
    @Published public var availableTools: [MCPTool] = []
    @Published public var lastError: String?
    
    private var serverPath: String
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    
    public init(serverPath: String = "../idl-rs/target/release/idl-mcp-server") {
        self.serverPath = serverPath
    }
    
    // MARK: - Connection
    
    public func connect() async throws {
        // Resolve server path
        let fm = FileManager.default
        let expandedPath = NSString(string: serverPath).expandingTildeInPath
        
        guard fm.fileExists(atPath: expandedPath) else {
            throw MCPError.serverNotFound(expandedPath)
        }
        
        // Spawn server process with stdio transport
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: expandedPath)
        proc.arguments = []  // MCP stdio mode is default
        
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr
        
        do {
            try proc.run()
            
            self.process = proc
            self.stdinPipe = stdin
            self.stdoutPipe = stdout
            self.stderrPipe = stderr
            self.isConnected = true
            self.lastError = nil
            
            // Fetch tool list (simulated; real MCP uses initialize + list_tools)
            await loadToolList()
            
        } catch {
            throw MCPError.spawnFailed(error.localizedDescription)
        }
    }
    
    public func disconnect() {
        process?.terminate()
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
        isConnected = false
        availableTools = []
    }
    
    // MARK: - Tool Discovery
    
    private func loadToolList() async {
        // Stub: populate with known W21+W24 tools
        // Real implementation would send MCP list_tools request
        
        var tools: [MCPTool] = []
        
        // Read tools
        tools.append(MCPTool(
            name: "idl.read_file",
            description: "Read an IDL file from the workspace"
        ))
        tools.append(MCPTool(
            name: "idl.list_files",
            description: "List all IDL files in the workspace"
        ))
        tools.append(MCPTool(
            name: "idl.get_node",
            description: "Get a specific node from the semantic graph"
        ))
        tools.append(MCPTool(
            name: "idl.list_nodes",
            description: "List all nodes in the semantic graph"
        ))
        tools.append(MCPTool(
            name: "idl.query_graph",
            description: "Query the semantic graph with filters"
        ))
        
        // Parse/Validate tools
        tools.append(MCPTool(
            name: "idl.parse",
            description: "Parse an IDL file and return AST"
        ))
        tools.append(MCPTool(
            name: "idl.validate",
            description: "Validate an IDL file for correctness"
        ))
        
        // Proposal tools (W24 mutations)
        tools.append(MCPTool(
            name: "idl.proposal.list",
            description: "List all proposals (optionally filter by status)"
        ))
        tools.append(MCPTool(
            name: "idl.proposal.get",
            description: "Get a specific proposal by ID"
        ))
        tools.append(MCPTool(
            name: "idl.proposal.create",
            description: "Create a new proposal (add/update/remove node or edge)"
        ))
        tools.append(MCPTool(
            name: "idl.proposal.accept",
            description: "Accept a pending proposal"
        ))
        tools.append(MCPTool(
            name: "idl.proposal.reject",
            description: "Reject a pending proposal with reason"
        ))
        
        self.availableTools = tools
    }
    
    // MARK: - Tool Invocation (W24 — Real JSON-RPC)
    
    private var requestId = 0
    
    public func callTool(name: String, arguments: [String: Any]) async throws -> [String: Any] {
        guard isConnected else {
            throw MCPError.spawnFailed("Not connected to MCP server")
        }
        
        guard let stdin = stdinPipe, let stdout = stdoutPipe else {
            throw MCPError.spawnFailed("Pipes not initialized")
        }
        
        requestId += 1
        let id = requestId
        
        // Build JSON-RPC 2.0 request
        let request: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id,
            "method": "tools/call",
            "params": [
                "name": name,
                "arguments": arguments
            ]
        ]
        
        // Serialize and send (with retry on EPIPE)
        do {
            let data = try JSONSerialization.data(withJSONObject: request)
            var line = String(data: data, encoding: .utf8) ?? ""
            line += "\n"
            
            if let lineData = line.data(using: .utf8) {
                try stdin.fileHandleForWriting.write(contentsOf: lineData)
            }
        } catch {
            // Retry once on transient EPIPE/timeout
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            let data = try JSONSerialization.data(withJSONObject: request)
            var line = String(data: data, encoding: .utf8) ?? ""
            line += "\n"
            if let lineData = line.data(using: .utf8) {
                try stdin.fileHandleForWriting.write(contentsOf: lineData)
            }
        }
        
        // Read response (with timeout)
        let responseData = try await withTimeout(seconds: 30) {
            return stdout.fileHandleForReading.availableData
        }
        
        guard !responseData.isEmpty else {
            throw MCPError.invalidResponse("Empty response from MCP server")
        }
        
        // Parse JSON-RPC response
        let response = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
        guard let response = response else {
            throw MCPError.invalidResponse("Response is not JSON object")
        }
        
        // Check for error
        if let error = response["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "Unknown error"
            throw MCPError.invalidResponse("MCP error: \(message)")
        }
        
        // Extract result
        guard let result = response["result"] as? [String: Any] else {
            throw MCPError.invalidResponse("Response missing 'result' field")
        }
        
        return result
    }
    
    private func withTimeout<T>(seconds: Double, operation: @escaping () throws -> T) async throws -> T {
        let task = Task {
            try operation()
        }
        
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            task.cancel()
        }
        
        let result = try await task.value
        timeoutTask.cancel()
        return result
    }
    
    // MARK: - Read Tools (Stubs)
    
    public func readFile(path: String) async throws -> String {
        let result = try await callTool(name: "idl.read_file", arguments: ["path": path])
        return result["content"] as? String ?? ""
    }
    
    public func listFiles() async throws -> [String] {
        let result = try await callTool(name: "idl.list_files", arguments: [:])
        return result["files"] as? [String] ?? []
    }
    
    public func getNode(id: String) async throws -> [String: Any] {
        try await callTool(name: "idl.get_node", arguments: ["id": id])
    }
    
    public func listNodes() async throws -> [[String: Any]] {
        let result = try await callTool(name: "idl.list_nodes", arguments: [:])
        return result["nodes"] as? [[String: Any]] ?? []
    }
    
    public func queryGraph(filter: [String: Any]) async throws -> [String: Any] {
        try await callTool(name: "idl.query_graph", arguments: ["filter": filter])
    }
    
    // MARK: - Proposal Tools (W24 — Full Mutation Support)
    
    public var proposalTools: [MCPTool] {
        availableTools.filter { $0.name.hasPrefix("idl.proposal.") }
    }
    
    // List all proposals
    public func listProposals(status: String? = nil) async throws -> [[String: Any]] {
        var args: [String: Any] = [:]
        if let status = status {
            args["status"] = status
        }
        let result = try await callTool(name: "idl.proposal.list", arguments: args)
        return result["proposals"] as? [[String: Any]] ?? []
    }
    
    // Get a specific proposal
    public func getProposal(id: String) async throws -> [String: Any] {
        try await callTool(name: "idl.proposal.get", arguments: ["id": id])
    }
    
    // Create a new proposal
    public func createProposal(type: String, data: [String: Any], reason: String) async throws -> [String: Any] {
        try await callTool(name: "idl.proposal.create", arguments: [
            "type": type,
            "data": data,
            "reason": reason
        ])
    }
    
    // Accept a proposal
    public func acceptProposal(id: String) async throws -> [String: Any] {
        try await callTool(name: "idl.proposal.accept", arguments: ["id": id])
    }
    
    // Reject a proposal
    public func rejectProposal(id: String, reason: String) async throws -> [String: Any] {
        try await callTool(name: "idl.proposal.reject", arguments: [
            "id": id,
            "reason": reason
        ])
    }
    
    // Parse an IDL file
    public func parseIDL(path: String) async throws -> [String: Any] {
        try await callTool(name: "idl.parse", arguments: ["path": path])
    }
    
    // Validate an IDL file
    public func validateIDL(path: String) async throws -> [String: Any] {
        try await callTool(name: "idl.validate", arguments: ["path": path])
    }
}
