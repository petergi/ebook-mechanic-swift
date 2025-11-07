import XCTest
import Foundation
@testable import EbookMechanicCore

#if canImport(PDFKit)
import PDFKit
#endif
#if canImport(AppKit)
import AppKit
#endif

final class PDFVerifierTests: XCTestCase {

    func tempURL(suffix: String = "pdf") -> URL {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory
        return dir.appendingPathComponent("test-")
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(suffix)
    }

    func writeDocument(_ doc: PDFDocument, to url: URL, options: [PDFDocumentWriteOption: Any]? = nil) throws {
        // Ensure parent exists
        let fm = FileManager.default
        let parent = url.deletingLastPathComponent()
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        let success: Bool
        if let opts = options {
            success = doc.write(to: url, withOptions: opts)
        } else {
            success = doc.write(to: url)
        }
        guard success else {
            throw NSError(domain: "PDFWrite", code: 1, userInfo: nil)
        }
    }

    func testTextPDFFingerprintStableAcrossMetadataChanges() throws {
        #if canImport(PDFKit) && canImport(AppKit)
        // Create a PDF with a single text page
        let attr = NSAttributedString(string: "Hello, world!\nLine two.", attributes: [NSAttributedString.Key.font: NSFont.systemFont(ofSize: 18)])
        let page = PDFPage(image: imageFromAttributedString(attr)) // create image from text to ensure page exists
        let doc = PDFDocument()
        if let page = page { doc.insert(page, at: 0) }

        let url1 = tempURL()
        try writeDocument(doc, to: url1)

        let fp1 = PDFVerifier.fingerprintResult(for: url1)

        // Change metadata
        doc.documentAttributes = [PDFDocumentAttribute.titleAttribute: "New Title"]
        let url2 = tempURL()
        try writeDocument(doc, to: url2)

        let fp2 = PDFVerifier.fingerprintResult(for: url2)

        XCTAssertEqual(fp1, fp2, "Fingerprint should not change when only metadata changes")
        #else
        throw XCTSkip("PDFKit/AppKit not available on this platform")
        #endif
    }

    func testImagePDFFingerprintStableAcrossMetadataChanges() throws {
        #if canImport(PDFKit) && canImport(AppKit)
        // Create an image-only PDF
        let image = sampleTestImage()
        guard let page = PDFPage(image: image) else { throw XCTSkip("Couldn't create PDFPage from image") }
        let doc = PDFDocument()
        doc.insert(page, at: 0)

        let url1 = tempURL()
        try writeDocument(doc, to: url1)
        let fp1 = PDFVerifier.fingerprintResult(for: url1)

        // Change metadata
        doc.documentAttributes = [PDFDocumentAttribute.authorAttribute: "Someone Else"]
        let url2 = tempURL()
        try writeDocument(doc, to: url2)
        let fp2 = PDFVerifier.fingerprintResult(for: url2)

        XCTAssertEqual(fp1, fp2, "Image-only PDF fingerprint should be stable across metadata changes")
        #else
        throw XCTSkip("PDFKit/AppKit not available on this platform")
        #endif
    }

    func testFingerprintDiffersWhenContentChanges() throws {
        #if canImport(PDFKit) && canImport(AppKit)
        // Create two documents with different text
        let a = NSAttributedString(string: "Content A", attributes: [NSAttributedString.Key.font: NSFont.systemFont(ofSize: 16)])
        let b = NSAttributedString(string: "Content B", attributes: [NSAttributedString.Key.font: NSFont.systemFont(ofSize: 16)])
        let pageA = PDFPage(image: imageFromAttributedString(a))
        let pageB = PDFPage(image: imageFromAttributedString(b))
        let docA = PDFDocument(); if let p = pageA { docA.insert(p, at: 0) }
        let docB = PDFDocument(); if let p = pageB { docB.insert(p, at: 0) }

        let urlA = tempURL(); try writeDocument(docA, to: urlA)
        let urlB = tempURL(); try writeDocument(docB, to: urlB)

        let fA = PDFVerifier.fingerprintResult(for: urlA)
        let fB = PDFVerifier.fingerprintResult(for: urlB)

        XCTAssertNotEqual(fA, fB, "Fingerprints should differ when content changes")
        #else
        throw XCTSkip("PDFKit/AppKit not available on this platform")
        #endif
    }

    func testEncryptedPDFFingerprint() throws {
        #if canImport(PDFKit) && canImport(AppKit)
        // Create a password-protected PDF
        let image = sampleTestImage()
        guard let page = PDFPage(image: image) else { throw XCTSkip("Couldn't create PDFPage from image") }
        let doc = PDFDocument()
        doc.insert(page, at: 0)

        // Write unencrypted copy
        let urlPlain = tempURL()
        try writeDocument(doc, to: urlPlain)
        let fpPlain = PDFVerifier.fingerprintResult(for: urlPlain)

        // Write encrypted copy using PDFDocument write options
        let urlEnc = tempURL()
        #if canImport(PDFKit)
        let options: [PDFDocumentWriteOption: Any] = [PDFDocumentWriteOption.userPasswordOption: "secret", PDFDocumentWriteOption.ownerPasswordOption: "owner"]
        try writeDocument(doc, to: urlEnc, options: options)
        let fpEnc = PDFVerifier.fingerprintResult(for: urlEnc)

        switch fpEnc {
        case .encrypted:
            break
        default:
            XCTFail("Expected encrypted fingerprint result for protected PDF, got: \(fpEnc)")
        }

        switch fpPlain {
        case .encrypted:
            XCTFail("Unencrypted PDF should not be reported as encrypted")
        default:
            break
        }
        #else
        throw XCTSkip("PDFKit not available for writing encrypted PDF")
        #endif
        #else
        throw XCTSkip("PDFKit/AppKit not available on this platform")
        #endif
    }

    // Helpers
    #if canImport(AppKit)
    func imageFromAttributedString(_ attr: NSAttributedString) -> NSImage {
        let size = attr.size()
        let img = NSImage(size: size)
        img.lockFocus()
        NSColor.white.set()
        NSRect(origin: .zero, size: size).fill()
        attr.draw(at: .zero)
        img.unlockFocus()
        return img
    }

    func sampleTestImage() -> NSImage {
        let size = NSSize(width: 400, height: 600)
        let img = NSImage(size: size)
        img.lockFocus()
        NSColor.red.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        NSColor.blue.setFill()
        NSBezierPath(ovalIn: NSRect(x: 50, y: 50, width: 300, height: 500)).fill()
        img.unlockFocus()
        return img
    }
    #endif
}
