import SwiftUI

struct DriftView: View {
    @State private var idlPath: String = ""
    @State private var codePath: String = ""
    @State private var isAnalyzing = false
    @State private var driftReport: String = ""
    @State private var errorMessage: String?
    
    var body: some View {
        HSplitView {
            // Left panel - configuration
            VStack(alignment: .leading, spacing: 16) {
                Text("Drift Analysis")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Compare IDL spec with actual implementation")
                    .foregroundColor(.secondary)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("IDL Specification")
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
                    Text("Implementation Directory")
                        .fontWeight(.semibold)
                    
                    HStack {
                        TextField("Path to code", text: $codePath)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Browse...") {
                            selectCodeDirectory()
                        }
                    }
                }
                
                Button(action: startAnalysis) {
                    if isAnalyzing {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Analyzing...")
                        }
                    } else {
                        Text("Analyze Drift")
                    }
                }
                .disabled(idlPath.isEmpty || codePath.isEmpty || isAnalyzing)
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
                    Text("Parity Matrix")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    Text("Reports structural and behavioral drift between IDL spec and implementation. See Wave 4 decisions for methodology.")
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
            
            // Right panel - drift report
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Drift Report")
                        .font(.headline)
                    
                    Spacer()
                    
                    if !driftReport.isEmpty {
                        Button("Export...") {
                            exportReport()
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                ScrollView {
                    Text(driftReport.isEmpty ? "No analysis run yet" : driftReport)
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
    
    private func selectCodeDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                codePath = url.path
            }
        }
    }
    
    private func startAnalysis() {
        isAnalyzing = true
        errorMessage = nil
        driftReport = "Starting drift analysis...\n"
        
        Task {
            do {
                let result = try await IDLCore.shared.analyzeDrift(
                    idlPath: idlPath,
                    codePath: codePath
                )
                await MainActor.run {
                    driftReport = result
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Analysis failed: \(error.localizedDescription)"
                    driftReport += "\n❌ Error: \(error.localizedDescription)"
                    isAnalyzing = false
                }
            }
        }
    }
    
    private func exportReport() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "drift-report.md"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? driftReport.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}
