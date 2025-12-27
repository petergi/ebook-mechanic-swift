import Compression
import Foundation

enum ZipError: Error, CustomStringConvertible {
  case invalidSignature
  case unsupportedCompression
  case malformedEntry
  case invalidUTF8
  case decodeFailure
  case dataDescriptorUnsupported

  var description: String {
    switch self {
    case .invalidSignature:
      return "ZIP archive has invalid signature"
    case .unsupportedCompression:
      return "ZIP archive uses unsupported compression method"
    case .malformedEntry:
      return "ZIP entry is malformed"
    case .invalidUTF8:
      return "ZIP entry contains non-UTF8 filename"
    case .decodeFailure:
      return "Unable to decode compressed ZIP entry"
    case .dataDescriptorUnsupported:
      return "ZIP archive uses data descriptors (unsupported in fast path)"
    }
  }
}

struct ZipEntry {
  var name: String
  var data: Data
  var compressionMethod: UInt16

  init(name: String, data: Data, compressionMethod: UInt16 = 0) {
    self.name = name
    self.data = data
    self.compressionMethod = compressionMethod
  }
}

struct ZipArchive {
  var entries: [ZipEntry]

  static func load(from url: URL) throws -> ZipArchive {
    let rawData = try Data(contentsOf: url)
    do {
      let entries = try parseLocalHeaders(rawData: rawData)
      return ZipArchive(entries: entries)
    } catch {
      let localError = error
      do {
        let entries = try parseCentralDirectory(rawData: rawData)
        return ZipArchive(entries: entries)
      } catch {
        throw localError
      }
    }
  }

  private static func parseLocalHeaders(rawData: Data) throws -> [ZipEntry] {
    var buffer = rawData
    var offset = buffer.startIndex
    var entries: [ZipEntry] = []

    while offset + 4 <= buffer.endIndex {
      let signature = buffer.readUInt32LE(at: offset)
      if signature == 0x0403_4b50 {
        guard let entry = try buffer.readLocalFileHeader(from: &offset) else {
          break
        }
        entries.append(entry)
      } else if signature == 0x0201_4b50 || signature == 0x0605_4b50 {
        break
      } else {
        throw ZipError.invalidSignature
      }
    }

    guard !entries.isEmpty else {
      throw ZipError.invalidSignature
    }
    return entries
  }

  private static func parseCentralDirectory(rawData: Data) throws -> [ZipEntry] {
    guard let eocdOffset = rawData.findEndOfCentralDirectory() else {
      throw ZipError.invalidSignature
    }

    let totalEntries = Int(rawData.readUInt16LE(at: eocdOffset + 10))
    let centralDirectorySize = Int(rawData.readUInt32LE(at: eocdOffset + 12))
    let centralDirectoryOffset = Int(rawData.readUInt32LE(at: eocdOffset + 16))
    guard centralDirectoryOffset + centralDirectorySize <= rawData.count else {
      throw ZipError.malformedEntry
    }

    var cursor = centralDirectoryOffset
    var entries: [ZipEntry] = []
    entries.reserveCapacity(max(0, totalEntries))

    while cursor < centralDirectoryOffset + centralDirectorySize {
      guard cursor + 46 <= rawData.count else { throw ZipError.malformedEntry }
      let signature = rawData.readUInt32LE(at: cursor)
      guard signature == 0x0201_4b50 else { throw ZipError.invalidSignature }

      let compressionMethod = rawData.readUInt16LE(at: cursor + 10)
      let compressedSize = Int(rawData.readUInt32LE(at: cursor + 20))
      let uncompressedSize = Int(rawData.readUInt32LE(at: cursor + 24))
      let fileNameLength = Int(rawData.readUInt16LE(at: cursor + 28))
      let extraLength = Int(rawData.readUInt16LE(at: cursor + 30))
      let commentLength = Int(rawData.readUInt16LE(at: cursor + 32))
      let localHeaderOffset = Int(rawData.readUInt32LE(at: cursor + 42))

      let nameStart = cursor + 46
      let nameEnd = nameStart + fileNameLength
      guard nameEnd <= rawData.count else { throw ZipError.malformedEntry }
      guard let name = String(data: rawData[nameStart..<nameEnd], encoding: .utf8) else {
        throw ZipError.invalidUTF8
      }

      cursor = nameEnd + extraLength + commentLength
      guard cursor <= rawData.count else { throw ZipError.malformedEntry }

      guard localHeaderOffset + 30 <= rawData.count else { throw ZipError.malformedEntry }
      let localSignature = rawData.readUInt32LE(at: localHeaderOffset)
      guard localSignature == 0x0403_4b50 else { throw ZipError.invalidSignature }

      let localNameLength = Int(rawData.readUInt16LE(at: localHeaderOffset + 26))
      let localExtraLength = Int(rawData.readUInt16LE(at: localHeaderOffset + 28))
      let dataStart = localHeaderOffset + 30 + localNameLength + localExtraLength
      let dataEnd = dataStart + compressedSize
      guard dataEnd <= rawData.count else { throw ZipError.malformedEntry }

      let compressedData = rawData[dataStart..<dataEnd]
      let data: Data
      switch compressionMethod {
      case 0:
        data = Data(compressedData)
      case 8:
        data = try Data.decompressDeflate(data: compressedData, expectedSize: uncompressedSize)
      default:
        throw ZipError.unsupportedCompression
      }

      entries.append(ZipEntry(name: name, data: data, compressionMethod: compressionMethod))
    }

    guard !entries.isEmpty else {
      throw ZipError.invalidSignature
    }
    return entries
  }

  func write(to url: URL) throws {
    var fileData = Data()
    var centralDirectory = Data()

    for entry in entries {
      guard let nameData = entry.name.data(using: .utf8) else {
        throw ZipError.invalidUTF8
      }

      let uncompressed = entry.data
      let method: UInt16
      let compressed: Data
      switch entry.compressionMethod {
      case 0:
        method = 0
        compressed = uncompressed
      case 8:
        method = 8
        compressed = try _compressDeflate(uncompressed)
      default:
        throw ZipError.unsupportedCompression
      }
      let crc = CRC32.checksum(uncompressed)
      let compSize = compressed.count
      let uncompSize = uncompressed.count

      let offset = fileData.count

      fileData.appendUInt32(0x0403_4b50)
      fileData.appendUInt16(20)  // version needed to extract
      fileData.appendUInt16(0x0800)  // general purpose bit flag (UTF-8)
      fileData.appendUInt16(method)
      fileData.appendUInt16(0)
      fileData.appendUInt16(0)
      fileData.appendUInt32(crc)
      fileData.appendUInt32(UInt32(compSize))
      fileData.appendUInt32(UInt32(uncompSize))
      fileData.appendUInt16(UInt16(nameData.count))
      fileData.appendUInt16(0)  // extra field length
      fileData.append(nameData)
      fileData.append(compressed)

      centralDirectory.appendUInt32(0x0201_4b50)
      centralDirectory.appendUInt16(0x031E)  // version made by (arbitrary)
      centralDirectory.appendUInt16(20)  // version needed to extract
      centralDirectory.appendUInt16(0x0800)
      centralDirectory.appendUInt16(method)
      centralDirectory.appendUInt16(0)
      centralDirectory.appendUInt16(0)
      centralDirectory.appendUInt32(crc)
      centralDirectory.appendUInt32(UInt32(compSize))
      centralDirectory.appendUInt32(UInt32(uncompSize))
      centralDirectory.appendUInt16(UInt16(nameData.count))
      centralDirectory.appendUInt16(0)  // extra field length
      centralDirectory.appendUInt16(0)  // comment length
      centralDirectory.appendUInt16(0)  // disk number start
      centralDirectory.appendUInt16(0)  // internal attributes
      centralDirectory.appendUInt32(0)  // external attributes
      centralDirectory.appendUInt32(UInt32(offset))
      centralDirectory.append(nameData)
    }

    let centralDirectoryOffset = fileData.count
    fileData.append(centralDirectory)

    fileData.appendUInt32(0x0605_4b50)
    fileData.appendUInt16(0)  // disk number
    fileData.appendUInt16(0)  // disk with central directory
    fileData.appendUInt16(UInt16(entries.count))
    fileData.appendUInt16(UInt16(entries.count))
    fileData.appendUInt32(UInt32(centralDirectory.count))
    fileData.appendUInt32(UInt32(centralDirectoryOffset))
    fileData.appendUInt16(0)  // comment length

    try fileData.write(to: url, options: .atomic)
  }

  func entry(named name: String) -> ZipEntry? {
    entries.first { $0.name == name }
  }
}

extension Data {
  fileprivate mutating func appendUInt16(_ value: UInt16) {
    var little = value.littleEndian
    Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
  }

  fileprivate mutating func appendUInt32(_ value: UInt32) {
    var little = value.littleEndian
    Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
  }

  fileprivate func readUInt16LE(at index: Int) -> UInt16 {
    let start = self.index(startIndex, offsetBy: index)
    let end = self.index(start, offsetBy: 2)
    return self[start..<end].withUnsafeBytes { buffer in
      buffer.loadUnaligned(as: UInt16.self).littleEndian
    }
  }

  fileprivate func readUInt32LE(at index: Int) -> UInt32 {
    let start = self.index(startIndex, offsetBy: index)
    let end = self.index(start, offsetBy: 4)
    return self[start..<end].withUnsafeBytes { buffer in
      buffer.loadUnaligned(as: UInt32.self).littleEndian
    }
  }

  fileprivate mutating func readLocalFileHeader(from offset: inout Int) throws -> ZipEntry? {
    guard offset + 30 <= endIndex else {
      throw ZipError.malformedEntry
    }

    let signature = readUInt32LE(at: offset)
    guard signature == 0x0403_4b50 else {
      return nil
    }

    let generalPurposeFlag = readUInt16LE(at: offset + 6)
    if generalPurposeFlag & 0x0008 != 0 {
      throw ZipError.dataDescriptorUnsupported
    }

    let compressionMethod: UInt16 = readUInt16LE(at: offset + 8)
    let compressedSize = Int(readUInt32LE(at: offset + 18))
    let uncompressedSize = Int(readUInt32LE(at: offset + 22))
    let nameLength = Int(readUInt16LE(at: offset + 26))
    let extraLength = Int(readUInt16LE(at: offset + 28))

    let nameStart = offset + 30
    let nameEnd = nameStart + nameLength
    guard nameEnd <= endIndex else {
      throw ZipError.malformedEntry
    }
    guard let name = String(data: self[nameStart..<nameEnd], encoding: String.Encoding.utf8) else {
      throw ZipError.invalidUTF8
    }

    let dataStart = nameEnd + extraLength
    let dataEnd = dataStart + compressedSize
    guard dataEnd <= endIndex else {
      throw ZipError.malformedEntry
    }

    let compressedData = self[dataStart..<dataEnd]
    let data: Data

    switch compressionMethod {
    case 0:
      data = Data(compressedData)
    case 8:
      data = try Data.decompressDeflate(data: compressedData, expectedSize: uncompressedSize)
    default:
      throw ZipError.unsupportedCompression
    }

    offset = dataEnd
    return ZipEntry(name: name, data: data, compressionMethod: compressionMethod)
  }

  fileprivate static func decompressDeflate(data: Data, expectedSize: Int) throws -> Data {
    var destination = Data(count: expectedSize)
    let capacity = destination.count
    let decodedSize = destination.withUnsafeMutableBytes { destPtr -> Int in
      data.withUnsafeBytes { srcPtr -> Int in
        compression_decode_buffer(
          destPtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
          capacity,
          srcPtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
          data.count,
          nil,
          COMPRESSION_ZLIB
        )
      }
    }

    guard decodedSize == expectedSize else {
      throw ZipError.decodeFailure
    }

    return destination
  }

  fileprivate func findEndOfCentralDirectory() -> Int? {
    let minEOCDSize = 22
    guard count >= minEOCDSize else { return nil }
    let maxCommentLength = 0xFFFF
    let searchStart = Swift.max(0, count - (maxCommentLength + minEOCDSize))
    var index = count - minEOCDSize
    while index >= searchStart {
      if readUInt32LE(at: index) == 0x0605_4b50 {
        return index
      }
      index -= 1
    }
    return nil
  }

  fileprivate func compressDeflate(data: Data) throws -> Data {
    let dstCapacity = compression_encode_scratch_buffer_size(COMPRESSION_ZLIB)
    let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(
      capacity: (data.count > 64 ? data.count : 64))
    let scratch = UnsafeMutableRawPointer.allocate(
      byteCount: dstCapacity, alignment: MemoryLayout<Int>.alignment)
    defer {
      dstBuffer.deallocate()
      scratch.deallocate()
    }
    var output = Data()
    data.withUnsafeBytes { srcPtr in
      let src = srcPtr.baseAddress!.assumingMemoryBound(to: UInt8.self)
      let compressedSize = compression_encode_buffer(
        dstBuffer, (data.count > 64 ? data.count : 64), src, data.count, scratch, COMPRESSION_ZLIB)
      if compressedSize > 0 {
        output.append(dstBuffer, count: compressedSize)
      }
    }
    return output
  }
}

private func _compressDeflate(_ data: Data) throws -> Data {
  // Allocate an output buffer that's reasonably larger than input to accommodate overhead.
  let initialCapacity = Swift.max(256, data.count + data.count / 16 + 64)
  var capacity = initialCapacity
  while true {
    let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
    defer { dstBuffer.deallocate() }
    let scratchSize = compression_encode_scratch_buffer_size(COMPRESSION_ZLIB)
    let scratch = UnsafeMutableRawPointer.allocate(
      byteCount: scratchSize, alignment: MemoryLayout<UInt8>.alignment)
    defer { scratch.deallocate() }
    var written = 0
    let result = data.withUnsafeBytes { srcPtr -> Int in
      guard let srcBase = srcPtr.baseAddress else { return 0 }
      return compression_encode_buffer(
        dstBuffer,
        capacity,
        srcBase.assumingMemoryBound(to: UInt8.self),
        data.count,
        scratch,
        COMPRESSION_ZLIB
      )
    }
    written = result
    if written > 0 && written <= capacity {
      return Data(bytes: dstBuffer, count: written)
    }
    // Increase capacity and retry if buffer was insufficient.
    capacity *= 2
    if capacity > data.count * 8 + 1024 {
      // Fallback: return original data if we somehow cannot compress sensibly.
      return data
    }
  }
}

private enum CRC32 {
  private static let table: [UInt32] = {
    (0..<256).map { index -> UInt32 in
      var crc = UInt32(index)
      for _ in 0..<8 {
        if crc & 1 == 1 {
          crc = 0xEDB8_8320 ^ (crc >> 1)
        } else {
          crc >>= 1
        }
      }
      return crc
    }
  }()

  static func checksum(_ data: Data) -> UInt32 {
    var crc: UInt32 = 0xFFFF_FFFF
    for byte in data {
      let index = Int((crc ^ UInt32(byte)) & 0xFF)
      crc = CRC32.table[index] ^ (crc >> 8)
    }
    return crc ^ 0xFFFF_FFFF
  }
}
