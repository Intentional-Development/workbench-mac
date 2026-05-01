import SwiftUI

struct EditorView: View {
    @State private var text: String = """
// Sample IDL Document
// ==============================================================================
// Module: sample
// Version: 0.1.0
// ==============================================================================

intent sample-intent {
  goal "Demonstrate IDL syntax in Workbench Mac"
  outcome "User can edit IDL with syntax highlighting"
  actors ["Developer"]
  priority "p1"
}

entity User {
  id string required
  name string required
  email string required
  created_at timestamp required
}

endpoint POST /api/users {
  intent sample-intent
  request {
    name string required
    email string required
  }
  response {
    user User required
  }
  errors [400, 500]
}
"""
    @State private var showFileImporter = false
    @State private var currentFilePath: URL?
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Button(action: { showFileImporter = true }) {
                    Label("Open", systemImage: "folder")
                }
                
                Button(action: saveFile) {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .disabled(currentFilePath == nil)
                
                Spacer()
                
                if let path = currentFilePath {
                    Text(path.lastPathComponent)
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Editor (basic TextEditor for now)
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.plainText],
            onCompletion: handleFileImport
        )
    }
    
    private func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    text = content
                    currentFilePath = url
                }
            }
        case .failure(let error):
            print("File import error: \(error)")
        }
    }
    
    private func saveFile() {
        guard let url = currentFilePath else { return }
        
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
