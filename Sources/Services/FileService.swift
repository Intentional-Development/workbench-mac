import Foundation

actor FileService {
    static let shared = FileService()
    
    private init() {}
    
    func readFile(at url: URL) throws -> String {
        guard url.startAccessingSecurityScopedResource() else {
            throw FileServiceError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        return try String(contentsOf: url, encoding: .utf8)
    }
    
    func writeFile(content: String, to url: URL) throws {
        guard url.startAccessingSecurityScopedResource() else {
            throw FileServiceError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    func listFiles(in directory: URL, withExtension ext: String) throws -> [URL] {
        guard directory.startAccessingSecurityScopedResource() else {
            throw FileServiceError.accessDenied
        }
        defer { directory.stopAccessingSecurityScopedResource() }
        
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        
        return contents.filter { $0.pathExtension == ext }
    }
}

enum FileServiceError: Error {
    case accessDenied
    case fileNotFound
    case invalidPath
}
