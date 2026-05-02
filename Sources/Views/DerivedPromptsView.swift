import SwiftUI
import AppKit

// MARK: - Derived Prompts View (W24)
//
// Generates IDE/tool-specific prompts from IDL specs.
// Targets: cursor, copilot, claude.
// Calls `idl prompts` via shell-out (MCP doesn't expose this yet — W25 FFI).

public enum PromptTarget: String, CaseIterable, Identifiable {
    case cursor = "cursor"
    case copilot = "copilot"
    case claude = "claude"
    
    public var id: String { rawValue }
    
    public var description: String {
        switch self {
        case .cursor: return "Cursor"
        case .copilot: return "GitHub Copilot"
        case .claude: return "Claude Desktop"
        }
    }
}

@MainActor
final class DerivedPromptsViewModel: ObservableObject {
    @Published var selectedTarget: PromptTarget = .cursor
    @Published var folderURL: URL?
    @Published var generatedPrompt: String = ""
    @Published var isGenerating: Bool = false
    @Published var error: String?
    
    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Choose IDL project folder"
        if panel.runModal() == .OK, let url = panel.url {
            folderURL = url
        }
    }
    
    func generatePrompt() async {
        guard let folder = folderURL else {
            error = "No folder selected"
            return
        }
        
        isGenerating = true
        error = nil
        generatedPrompt = ""
        
        do {
            // Bridge to workbench-cli or idl-cli binary
            // Real implementation: call `idl prompts --target <target> <folder>`
            // For now, shell out (W25 will replace with FFI)
            
            let idlCliPath = findIDLCLI()
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = [
                "-c",
                "\(idlCliPath) prompts --target \(selectedTarget.rawValue) \(folder.path)"
            ]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            if process.terminationStatus == 0 {
                generatedPrompt = output
            } else {
                error = "Failed to generate prompt: \(output)"
            }
        } catch {
            self.error = "Error: \(error.localizedDescription)"
        }
        
        isGenerating = false
    }
    
    func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(generatedPrompt, forType: .string)
    }
    
    private func findIDLCLI() -> String {
        // Try to find idl-cli binary
        // Priority: ../idl-rs/target/release/idl-cli, ../workbench-cli/dist/cli.js, fallback to stub
        
        let fm = FileManager.default
        let candidates = [
            "../idl-rs/target/release/idl-cli",
            "../workbench-cli/dist/cli.js"
        ]
        
        for candidate in candidates {
            let expanded = NSString(string: candidate).expandingTildeInPath
            if fm.fileExists(atPath: expanded) {
                return expanded
            }
        }
        
        // Fallback: return stub that outputs placeholder
        return "echo"
    }
}

struct DerivedPromptsView: View {
    @StateObject private var model = DerivedPromptsViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header + Controls
            VStack(alignment: .leading, spacing: 16) {
                Text("Derived Prompts")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                HStack(spacing: 16) {
                    // Folder picker
                    VStack(alignment: .leading, spacing: 4) {
                        Text("IDL Project")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            Text(model.folderURL?.lastPathComponent ?? "No folder selected")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(model.folderURL == nil ? .secondary : .primary)
                            
                            Button("Choose Folder") {
                                model.chooseFolder()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    Spacer()
                    
                    // Target picker
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Target")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Picker("Target", selection: $model.selectedTarget) {
                            ForEach(PromptTarget.allCases) { target in
                                Text(target.description).tag(target)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 300)
                    }
                }
                
                HStack {
                    Button("Generate Prompt") {
                        Task {
                            await model.generatePrompt()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.folderURL == nil || model.isGenerating)
                    
                    if model.isGenerating {
                        ProgressView()
                            .controlSize(.small)
                    }
                    
                    Spacer()
                    
                    Button("Copy to Clipboard") {
                        model.copyToClipboard()
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.generatedPrompt.isEmpty)
                }
            }
            .padding()
            
            Divider()
            
            // Prompt output
            ScrollView {
                if let error = model.error {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Error", systemImage: "exclamationmark.triangle")
                            .font(.headline)
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else if model.generatedPrompt.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Select a folder and target, then click Generate Prompt")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Generated Prompt for \(model.selectedTarget.description)")
                                .font(.headline)
                            Spacer()
                            Text("\(model.generatedPrompt.count) characters")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(model.generatedPrompt)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(12)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
