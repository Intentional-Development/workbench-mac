import XCTest
@testable import WorkbenchMac

// MARK: - Derived Prompts Tests (W24)
//
// Tests for DerivedPromptsView target enum and view model logic.

final class DerivedPromptsTests: XCTestCase {
    
    func testPromptTargetEnum() {
        XCTAssertEqual(PromptTarget.cursor.rawValue, "cursor")
        XCTAssertEqual(PromptTarget.copilot.rawValue, "copilot")
        XCTAssertEqual(PromptTarget.claude.rawValue, "claude")
        
        XCTAssertEqual(PromptTarget.allCases.count, 3)
    }
    
    func testPromptTargetDescriptions() {
        XCTAssertEqual(PromptTarget.cursor.description, "Cursor")
        XCTAssertEqual(PromptTarget.copilot.description, "GitHub Copilot")
        XCTAssertEqual(PromptTarget.claude.description, "Claude Desktop")
    }
    
    @MainActor
    func testViewModelInitialState() {
        let model = DerivedPromptsViewModel()
        
        XCTAssertEqual(model.selectedTarget, .cursor)
        XCTAssertNil(model.folderURL)
        XCTAssertEqual(model.generatedPrompt, "")
        XCTAssertFalse(model.isGenerating)
        XCTAssertNil(model.error)
    }
}
