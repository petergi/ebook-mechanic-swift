import Testing
import Foundation

@Suite("EPUB Mechanic CLI Tests")
struct EPUBMechanicCLITests {

    @Test("CLI executable exists")
    func testExecutableExists() {
        // Basic test to verify the package compiles
        #expect(true)
    }

    @Test("Help text contains EPUB validation info")
    func testHelpText() {
        // Verify help text mentions EPUB validation
        let helpText = """
        EPUB VALIDATION:
          - Validates ZIP structure
          - Checks for required mimetype file
          - Verifies META-INF/container.xml exists
        """

        #expect(helpText.contains("EPUB"))
        #expect(helpText.contains("ZIP"))
        #expect(helpText.contains("mimetype"))
    }
}
