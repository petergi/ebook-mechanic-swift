import Foundation
import Compression

enum ZipError: Error, CustomStringConvertible {
    case invalidSignature
    case unsupportedCompression
    case malformedEntry
    case invalidUTF8
    case decodeFailure

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
        }
    }
}

struct ZipEntry {
    var name: String
    var data: Data
}

struct ZipArchive {
    var entries: [ZipEntry]

    static func load(from url: URL) throws -> ZipArchive {
        var rawData = try Data(contentsOf: url)
        var offset = rawData.startIndex
        var entries: [ZipEntry] = []

        while offset + 4 <= rawData.endIndex {
            let signature = rawData.readUInt32LE(at: offset)
            if signature == 0x04034b50 { // Local file header
                guard let entry = try rawData.readLocalFileHeader(from: &offset) else {
                    break
                }
                entries.append(entry)
            } else if signature == 0x02014b50 || signature == 0x06054b50 {
                // Central directory or end of central directory: we're done.
                break
            } else {
                throw ZipError.invalidSignature
            }
        }

        return ZipArchive(entries: entries)
    }

    func write(to url: URL) throws {
        var fileData = Data()
        var centralDirectory = Data()

        for entry in entries {
            guard let nameData = entry.name.data(using: .utf8) else {
                throw ZipError.invalidUTF8
            }

            let offset = fileData.count

            let crc = CRC32.checksum(entry.data)
            fileData.appendUInt32(0x04034b50)
            fileData.appendUInt16(20) // version needed to extract
            fileData.appendUInt16(0x0800) // general purpose bit flag (UTF-8)
            fileData.appendUInt16(0) // compression method: stored
            fileData.appendUInt16(0)
            fileData.appendUInt16(0)
            fileData.appendUInt32(crc)
            fileData.appendUInt32(UInt32(entry.data.count))
            fileData.appendUInt32(UInt32(entry.data.count))
            fileData.appendUInt16(UInt16(nameData.count))
            fileData.appendUInt16(0) // extra field length
            fileData.append(nameData)
            fileData.append(entry.data)

            centralDirectory.appendUInt32(0x02014b50)
            centralDirectory.appendUInt16(0x031E) // version made by (arbitrary)
            centralDirectory.appendUInt16(20) // version needed to extract
            centralDirectory.appendUInt16(0x0800)
            centralDirectory.appendUInt16(0)
            centralDirectory.appendUInt16(0)
            centralDirectory.appendUInt16(0)
            centralDirectory.appendUInt32(crc)
            centralDirectory.appendUInt32(UInt32(entry.data.count))
            centralDirectory.appendUInt32(UInt32(entry.data.count))
            centralDirectory.appendUInt16(UInt16(nameData.count))
            centralDirectory.appendUInt16(0) // extra field length
            centralDirectory.appendUInt16(0) // comment length
            centralDirectory.appendUInt16(0) // disk number start
            centralDirectory.appendUInt16(0) // internal attributes
            centralDirectory.appendUInt32(0) // external attributes
            centralDirectory.appendUInt32(UInt32(offset))
            centralDirectory.append(nameData)
        }

        let centralDirectoryOffset = fileData.count
        fileData.append(centralDirectory)

        fileData.appendUInt32(0x06054b50)
        fileData.appendUInt16(0) // disk number
        fileData.appendUInt16(0) // disk with central directory
        fileData.appendUInt16(UInt16(entries.count))
        fileData.appendUInt16(UInt16(entries.count))
        fileData.appendUInt32(UInt32(centralDirectory.count))
        fileData.appendUInt32(UInt32(centralDirectoryOffset))
        fileData.appendUInt16(0) // comment length

        try fileData.write(to: url, options: .atomic)
    }

    func entry(named name: String) -> ZipEntry? {
        entries.first { $0.name == name }
    }
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }

    mutating func appendUInt32(_ value: UInt32) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }

    func readUInt16LE(at index: Int) -> UInt16 {
        let start = self.index(startIndex, offsetBy: index)
        let end = self.index(start, offsetBy: 2)
        return self[start..<end].withUnsafeBytes { buffer in
            buffer.loadUnaligned(as: UInt16.self).littleEndian
        }
    }

    func readUInt32LE(at index: Int) -> UInt32 {
        let start = self.index(startIndex, offsetBy: index)
        let end = self.index(start, offsetBy: 4)
        return self[start..<end].withUnsafeBytes { buffer in
            buffer.loadUnaligned(as: UInt32.self).littleEndian
        }
    }

    mutating func readLocalFileHeader(from offset: inout Int) throws -> ZipEntry? {
        guard offset + 30 <= endIndex else {
            throw ZipError.malformedEntry
        }

        let signature = readUInt32LE(at: offset)
        guard signature == 0x04034b50 else {
            return nil
        }

        let compressionMethod = readUInt16LE(at: offset + 8)
        let compressedSize = Int(readUInt32LE(at: offset + 18))
        let uncompressedSize = Int(readUInt32LE(at: offset + 22))
        let nameLength = Int(readUInt16LE(at: offset + 26))
        let extraLength = Int(readUInt16LE(at: offset + 28))

        let nameStart = offset + 30
        let nameEnd = nameStart + nameLength
        guard nameEnd <= endIndex else {
            throw ZipError.malformedEntry
        }
        guard let name = String(data: self[nameStart..<nameEnd], encoding: .utf8) else {
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
            data = try decompressDeflate(data: compressedData, expectedSize: uncompressedSize)
        default:
            throw ZipError.unsupportedCompression
        }

        offset = dataEnd
        return ZipEntry(name: name, data: data)
    }

    func decompressDeflate(data: Data, expectedSize: Int) throws -> Data {
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
}

private enum CRC32 {
    private static let table: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var crc = UInt32(i)
            for _ in 0..<8 {
                if crc & 1 == 1 {
                    crc = 0xEDB88320 ^ (crc >> 1)
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
