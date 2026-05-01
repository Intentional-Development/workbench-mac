import SwiftUI

struct EmitView: View {
    @State private var idlPath: String = ""
    @State private var selectedTarget: String = "node"
    @State private var outputPath: String = ""
    @State private var isEmitting = false
    @State private var emitLog: String = ""
    @State private var errorMessage: String?
    
    let targets = ["node", "go", "python", "rust"]
    
    var body: some View {
        HSplitView {
            // Left panel - configuration
            VStack(alignment: .leading, spacing: 16) {
                Text("Code Generation")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Generate code from IDL specification")
                    .foregroundColor(.secondary)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("IDL File")
                        .fontWeight(.semibold)
                    
                    HStack {
                        TextField("Path to .idl file", text: $idlPath)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Browse...") {
                            selectIDLFile()
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Language")
                        .fontWeight(.semibold)
                    
                    Picker("", selection: $selectedTarget) {
                        ForEach(targets, id: \.self) { target in
                            Text(target.capitalized).tag(target)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Output Directory")
                        .fontWeight(.semibold)
                    
                    HStack {
                        TextField("Output path", text: $outputPath)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Browse...") {
                            selectOutputDirectory()
                        }
                    }
                }
                
                Button(action: startEmit) {
                    if isEmitting {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Generating...")
                        }
                    } else {
                        Text("Generate Code")
                    }
                }
                .disabled(idlPath.isEmpty || outputPath.isEmpty || isEmitting)
                .buttonStyle(.borderedProminent)
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.vertical, 4)
                }
                
                Spacer()
            }
            .padding()
            .frame(minWidth: 300, maxWidth: 400)
            
            // Right panel - output log
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Generation Log")
                        .font(.headline)
                    
                    Spacer()
                    
                    if !emitLog.isEmpty {
                        Button("Clear") {
                            emitLog = ""
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                ScrollView {
                    Text(emitLog.isEmpty ? "No generation started yet" : emitLog)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .textSelection(.enabled)
                }
            }
        }
    }
    
    private func selectIDLFile() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.plainText]
        openPanel.canChooseDirectories = false
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                idlPath = url.path
            }
        }
    }
    
    private func selectOutputDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                outputPath = url.path
            }
        }
    }
    
    private func startEmit() {
        isEmitting = true
        errorMessage = nil
        emitLog = "Starting code generation for \(selectedTarget)...\n"
        
        Task {
            do {
                let result = try await IDLCore.shared.emitCode(
                    idlPath: idlPath,
                    target: selectedTarget,
                    outputPath: outputPath
                )
                await MainActor.run {
                    emitLog += result
                    emitLog += "\n✅ Code generation completed successfully"
                    isEmitting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Generation failed: \(error.localizedDescription)"
                    emitLog += "\n❌ Error: \(error.localizedDescription)"
                    isEmitting = false
                }
            }
        }
    }
}
