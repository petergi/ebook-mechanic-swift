import CryptoKit
import Foundation

public enum PDFVerifierError: Error {
  case cannotOpenDocument
  case emptyDocument
}

public struct PDFVerifier {

  // Placeholder: This will eventually be replaced by calls to pdfcpu library for a robust fingerprint.
  // For now, it will use a simple file hash.
  public static func fingerprintResult(for url: URL) -> FingerprintResult {
    do {
      let fileData = try Data(contentsOf: url)
      let hash = sha256Hex(fileData)
      return .fileHash(hash)
    } catch {
      return .unavailable("Failed to compute fingerprint: \(error.localizedDescription)")
    }
  }

  private static func sha256Hex(_ data: Data) -> String {
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
  }
}
