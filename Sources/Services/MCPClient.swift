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
        // Stub: populate with known W21 tools
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
        
        // Proposal tools (W24 mutations)
        tools.append(MCPTool(
            name: "idl.proposal.add_node",
            description: "Propose adding a new node to the graph"
        ))
        tools.append(MCPTool(
            name: "idl.proposal.update_node",
            description: "Propose updating an existing node"
        ))
        tools.append(MCPTool(
            name: "idl.proposal.remove_node",
            description: "Propose removing a node from the graph"
        ))
        tools.append(MCPTool(
            name: "idl.proposal.add_edge",
            description: "Propose adding a new edge between nodes"
        ))
        tools.append(MCPTool(
            name: "idl.proposal.remove_edge",
            description: "Propose removing an edge from the graph"
        ))
        
        self.availableTools = tools
    }
    
    // MARK: - Tool Invocation (Stub)
    
    public func callTool(name: String, arguments: [String: Any]) async throws -> [String: Any] {
        guard isConnected else {
            throw MCPError.spawnFailed("Not connected to MCP server")
        }
        
        // Stub: real implementation would send JSON-RPC 2.0 request over stdin/stdout
        // For W23, just return placeholder
        
        return [
            "tool": name,
            "status": "stub",
            "message": "MCP tool invocation scaffold — full implementation in W24"
        ]
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
    
    // MARK: - Proposal Tools (W24 — read-only listing for now)
    
    public var proposalTools: [MCPTool] {
        availableTools.filter { $0.name.hasPrefix("idl.proposal.") }
    }
}
