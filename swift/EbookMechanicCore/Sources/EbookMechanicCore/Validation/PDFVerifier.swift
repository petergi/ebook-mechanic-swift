import Foundation
#if canImport(PDFKit)
import PDFKit
#endif
#if canImport(AppKit)
import AppKit
#endif
import CryptoKit

public enum PDFVerifierError: Error {
    case cannotOpenDocument
    case emptyDocument
}

public struct PDFVerifier {
    /// Compute a content-based fingerprint for a PDF file.
    ///
    /// Strategy:
    /// - Try to open the file with PDFKit. If that fails, fall back to a raw file SHA256.
    /// - For each page, try to extract text. If text exists, normalize it and include it.
    /// - If a page has no text, and AppKit is available, render the page to an image and hash the image bytes.
    /// - Combine per-page parts in order and return a SHA256 hex string of the combined data.
    public static func fingerprint(for url: URL) throws -> String {
        let fileData = try Data(contentsOf: url)

        #if canImport(PDFKit)
        guard let doc = PDFDocument(data: fileData) else {
            // Can't parse as PDF with PDFKit — return file-level hash as a fallback
            return sha256Hex(fileData)
        }

        guard doc.pageCount > 0 else {
            throw PDFVerifierError.emptyDocument
        }

        var parts: [String] = []

        for idx in 0..<doc.pageCount {
            guard let page = doc.page(at: idx) else { continue }

            if let rawText = page.string, !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Normalize whitespace and unicode
                let normalized = rawText.precomposedStringWithCanonicalMapping
                let collapsed = normalized
                    .components(separatedBy: .whitespacesAndNewlines)
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                // Use text marker so images/text are distinguished
                parts.append("TXT:")
                parts.append(collapsed)
            } else {
                // No text on the page — try rendering to an image (macOS/iOS) and hash image bytes
                #if canImport(AppKit)
                // Render a reasonably large thumbnail to capture visual content
                let target = CGSize(width: 1024, height: 1024)
                let image = page.thumbnail(of: target, for: .mediaBox)

                // Try TIFF representation first
                if let tiff = image.tiffRepresentation {
                    let imgHash = sha256Hex(tiff)
                    parts.append("IMG:")
                    parts.append(imgHash)
                } else if let rep = image.representations.first, let data = rep.bitmapRepresentationData() {
                    parts.append("IMG:")
                    parts.append(sha256Hex(data))
                } else {
                    // Fallback: encode PNG representation from an NSBitmapImageRep if possible
                    if let finalData = image.tiffRepresentation {
                        parts.append("IMG:")
                        parts.append(sha256Hex(finalData))
                    } else {
                        parts.append("IMG:empty")
                    }
                }
                #else
                // No AppKit — fallback to a page placeholder
                parts.append("PAGE:")
                parts.append(String(idx))
                #endif
            }
        }

        let combined = parts.joined(separator: "\n")
        return sha256Hex(Data(combined.utf8))
        #else
        // PDFKit not available — fall back to raw file hash
        return sha256Hex(fileData)
        #endif
    }

    private static func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// Helper to try to extract raw bitmap data from an NSImageRep if available
#if canImport(AppKit)
extension NSImageRep {
    func bitmapRepresentationData() -> Data? {
        if let bmp = self as? NSBitmapImageRep {
            return bmp.representation(using: .png, properties: [:])
        }
        return nil
    }
}
#endif
