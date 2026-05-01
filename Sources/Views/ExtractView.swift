import SwiftUI

struct ExtractView: View {
    @State private var sourcePath: String = ""
    @State private var isExtracting = false
    @State private var extractedIDL: String = ""
    @State private var errorMessage: String?
    @State private var showDirectoryPicker = false
    
    var body: some View {
        HSplitView {
            // Left panel - configuration
            VStack(alignment: .leading, spacing: 16) {
                Text("Brownfield Extraction")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Extract IDL from existing codebase")
                    .foregroundColor(.secondary)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Source Directory")
                        .fontWeight(.semibold)
                    
                    HStack {
                        TextField("Path to source code", text: $sourcePath)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Browse...") {
                            showDirectoryPicker = true
                        }
                    }
                }
                
                Button(action: startExtraction) {
                    if isExtracting {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Extracting...")
                        }
                    } else {
                        Text("Extract IDL")
                    }
                }
                .disabled(sourcePath.isEmpty || isExtracting)
                .buttonStyle(.borderedProminent)
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.vertical, 4)
                }
                
                Spacer()
                
                // Info box
                VStack(alignment: .leading, spacing: 8) {
                    Text("Note: Temporary Bridge")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    Text("Currently shells out to workbench-cli. Will be replaced with Rust FFI via idl-core once Stark's swift-bridge implementation lands.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            .padding()
            .frame(minWidth: 300, maxWidth: 400)
            
            // Right panel - results
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Extracted IDL")
                        .font(.headline)
                    
                    Spacer()
                    
                    if !extractedIDL.isEmpty {
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(extractedIDL, forType: .string)
                        }
                        
                        Button("Save As...") {
                            saveExtractedIDL()
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                ScrollView {
                    Text(extractedIDL.isEmpty ? "No IDL extracted yet" : extractedIDL)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .textSelection(.enabled)
                }
            }
        }
        .fileImporter(
            isPresented: $showDirectoryPicker,
            allowedContentTypes: [.folder],
            onCompletion: handleDirectorySelection
        )
    }
    
    private func handleDirectorySelection(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            sourcePath = url.path
        case .failure:
            break
        }
    }
    
    private func startExtraction() {
        isExtracting = true
        errorMessage = nil
        extractedIDL = ""
        
        Task {
            do {
                let result = try await IDLCore.shared.extractIDL(from: sourcePath)
                await MainActor.run {
                    extractedIDL = result
                    isExtracting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Extraction failed: \(error.localizedDescription)"
                    isExtracting = false
                }
            }
        }
    }
    
    private func saveExtractedIDL() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "extracted.idl"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? extractedIDL.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}
