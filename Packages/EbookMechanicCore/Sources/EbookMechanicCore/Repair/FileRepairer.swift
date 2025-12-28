import Foundation

// swiftlint:disable type_body_length file_length cyclomatic_complexity function_body_length

/// Provides best-effort automated fixes for common ebook issues.
public struct FileRepairer: @unchecked Sendable {
  private let fileManager: FileManager
  private let validator: FileValidator

  public init(fileManager: FileManager = .default, validator: FileValidator = FileValidator()) {
    self.fileManager = fileManager
    self.validator = validator
  }

  /// Attempts to repair the file located at `url`.
  public func repair(url: URL) async -> RepairResult {
    guard let type = EbookFileType(pathExtension: url.pathExtension) else {
      return RepairResult(
        success: false, message: "Unknown file type, cannot repair", fixed: false, fileURL: url)
    }

    switch type {
    case .epub:
      return await repairEPUB(at: url)
    case .pdf, .azw4:
      return await repairPDF(at: url)
    case .mobi, .azw3:
      return await repairMOBI(at: url)
    }
  }

  private func repairEPUB(at url: URL) async -> RepairResult {
    let validation = await validator.validate(url: url, as: .epub)
    guard !validation.isValid else {
      return RepairResult(
        success: true, message: "File is already valid, no repair needed", fixed: false,
        fileURL: url)
    }

    let backupURL = url.appendingPathExtension("backup")
    do {
      try copyFile(from: url, to: backupURL)
    } catch {
      return RepairResult(
        success: false, message: "Failed to create backup: \(error.localizedDescription)",
        fixed: false, fileURL: url)
    }

    do {
      var archive = try ZipArchive.load(from: url)
      var fixed = false

      let expectedMimeData = Data("application/epub+zip".utf8)
      var entries = archive.entries

      func ensureMimetypeIsFirstStored() {
        var needsInsert = true
        if let index = entries.firstIndex(where: { $0.name == "mimetype" }) {
          // Check if mimetype is correctly positioned, uncompressed, and has correct content
          let isCorrect =
            index == 0 && entries[index].compressionMethod == 0
            && entries[index].data == expectedMimeData

          if isCorrect {
            needsInsert = false
          } else {
            // Remove incorrect mimetype entry for reinsertion
            if index != 0 {
              // Mimetype is not first - needs reordering
              fixed = true
            }
            if entries[index].compressionMethod != 0 {
              // Mimetype is compressed - needs decompression
              fixed = true
            }
            if entries[index].data != expectedMimeData {
              // Mimetype has wrong content - needs correction
              fixed = true
            }
            entries.remove(at: index)
          }
        }

        if needsInsert {
          // Insert correct mimetype as first entry, uncompressed
          entries.insert(
            ZipEntry(name: "mimetype", data: expectedMimeData, compressionMethod: 0), at: 0)
          fixed = true
        }
      }

      func ensureContainerExists() {
        let normalizedName = "META-INF/container.xml"
        if let idx = entries.firstIndex(where: {
          $0.name.caseInsensitiveCompare(normalizedName) == .orderedSame
        }) {
          if entries[idx].name != normalizedName {
            entries[idx].name = normalizedName
            fixed = true
          }
        } else {
          entries.append(
            ZipEntry(
              name: normalizedName, data: Data(Self.defaultContainerXML.utf8), compressionMethod: 8)
          )
          fixed = true
        }
      }

      func ensureValidOPF(containerData: Data, entries: inout [ZipEntry]) -> Bool {
        var opfFixed = false

        // Extract OPF path from container.xml
        guard let opfPath = extractOPFPathFromContainer(containerData) else {
          // Cannot parse container.xml, cannot repair OPF
          return false
        }

        // Check if OPF file exists
        let opfIndex = entries.firstIndex {
          $0.name.caseInsensitiveCompare(opfPath) == .orderedSame
        }

        if let idx = opfIndex {
          // OPF exists, validate it's parseable XML
          let opfData = entries[idx].data
          guard let document = try? XMLDocument(data: opfData, options: []) else {
            // OPF is corrupted, try to create a minimal valid one
            let minimalOPF = createMinimalOPF(htmlFiles: entries.filter { isHTMLFile($0.name) })
            entries[idx].data = minimalOPF
            return true
          }

          if repairMissingManifestResources(
            document: document,
            opfPath: entries[idx].name,
            entries: entries
          ) {
            entries[idx].data = Data(document.xmlString(options: [.nodePrettyPrint]).utf8)
            opfFixed = true
          }
        } else {
          // OPF doesn't exist, create it
          let minimalOPF = createMinimalOPF(htmlFiles: entries.filter { isHTMLFile($0.name) })
          entries.append(ZipEntry(name: opfPath, data: minimalOPF, compressionMethod: 8))
          opfFixed = true
        }

        return opfFixed
      }

      func extractOPFPathFromContainer(_ containerData: Data) -> String? {
        guard let doc = try? XMLDocument(data: containerData, options: []),
          let root = doc.rootElement(),
          let rootfiles = root.elements(forName: "rootfiles").first,
          let rootfile = rootfiles.elements(forName: "rootfile").first,
          let path = rootfile.attribute(forName: "full-path")?.stringValue
        else {
          return nil
        }
        return path
      }

      func createMinimalOPF(htmlFiles: [ZipEntry]) -> Data {
        let package = XMLElement(name: "package")
        if let versionAttribute = XMLNode.attribute(withName: "version", stringValue: "2.0")
          as? XMLNode {
          package.addAttribute(versionAttribute)
        }
        if let idAttribute = XMLNode.attribute(withName: "unique-identifier", stringValue: "BookId")
          as? XMLNode {
          package.addAttribute(idAttribute)
        }
        if let namespace = XMLNode.namespace(withName: "", stringValue: "http://www.idpf.org/2007/opf")
          as? XMLNode {
          package.addNamespace(namespace)
        }

        let metadata = XMLElement(name: "metadata")
        if let namespace = XMLNode.namespace(
          withName: "dc", stringValue: "http://purl.org/dc/elements/1.1/"
        ) as? XMLNode {
          metadata.addNamespace(namespace)
        }
        let title = XMLElement(name: "dc:title", stringValue: "Repaired EPUB")
        let identifier = XMLElement(name: "dc:identifier", stringValue: UUID().uuidString)
        if let attribute = XMLNode.attribute(withName: "id", stringValue: "BookId") as? XMLNode {
          identifier.addAttribute(attribute)
        }
        let language = XMLElement(name: "dc:language", stringValue: "en")
        metadata.addChild(title)
        metadata.addChild(identifier)
        metadata.addChild(language)

        let manifest = XMLElement(name: "manifest")
        let spine = XMLElement(name: "spine")

        // Add HTML files to manifest and spine
        for (index, htmlFile) in htmlFiles.enumerated() {
          let id = "item-\(index + 1)"
          let item = XMLElement(name: "item")
          if let attribute = XMLNode.attribute(withName: "id", stringValue: id) as? XMLNode {
            item.addAttribute(attribute)
          }
          if let attribute = XMLNode.attribute(withName: "href", stringValue: htmlFile.name)
            as? XMLNode {
            item.addAttribute(attribute)
          }
          if let attribute = XMLNode.attribute(
            withName: "media-type", stringValue: "application/xhtml+xml"
          ) as? XMLNode {
            item.addAttribute(attribute)
          }
          manifest.addChild(item)

          let itemref = XMLElement(name: "itemref")
          if let attribute = XMLNode.attribute(withName: "idref", stringValue: id) as? XMLNode {
            itemref.addAttribute(attribute)
          }
          spine.addChild(itemref)
        }

        package.addChild(metadata)
        package.addChild(manifest)
        package.addChild(spine)

        let doc = XMLDocument(rootElement: package)
        doc.characterEncoding = "UTF-8"
        doc.version = "1.0"
        return Data(doc.xmlString(options: [.nodePrettyPrint]).utf8)
      }

      func isHTMLFile(_ name: String) -> Bool {
        let lowercased = name.lowercased()
        return lowercased.hasSuffix(".html") || lowercased.hasSuffix(".xhtml")
          || lowercased.hasSuffix(".htm")
      }

      func repairMissingManifestResources(
        document: XMLDocument,
        opfPath: String,
        entries: [ZipEntry]
      ) -> Bool {
        guard let packageElement = document.rootElement(),
          let manifest = packageElement.elements(forName: "manifest").first
        else {
          return false
        }

        let opfDirectory = (opfPath as NSString).deletingLastPathComponent
        let entryNames = Set(entries.map { $0.name })
        var normalizedEntryMap: [String: String] = [:]
        normalizedEntryMap.reserveCapacity(entries.count)

        func normalizedPath(_ path: String) -> String {
          let lowercased = path.lowercased()
          return lowercased.removingPercentEncoding ?? lowercased
        }

        func resolveHref(_ href: String, relativeTo base: String) -> String {
          let hrefWithoutFragment = href.split(separator: "#").first.map(String.init) ?? href

          if base.isEmpty {
            return hrefWithoutFragment
          }

          var components = base.split(separator: "/").map(String.init)
          let segments = hrefWithoutFragment.split(separator: "/").map(String.init)

          for segment in segments {
            if segment == ".." {
              if !components.isEmpty {
                components.removeLast()
              }
            } else if segment == "." || segment.isEmpty {
              continue
            } else {
              components.append(segment)
            }
          }

          return components.joined(separator: "/")
        }

        func relativeHref(for entryName: String, base: String) -> String {
          guard !base.isEmpty else { return entryName }
          let prefix = base + "/"
          if entryName.hasPrefix(prefix) {
            return String(entryName.dropFirst(prefix.count))
          }
          return entryName
        }

        for entry in entries {
          let key = normalizedPath(entry.name)
          if normalizedEntryMap[key] == nil {
            normalizedEntryMap[key] = entry.name
          }
        }

        var removedIDs = Set<String>()
        var fixed = false

        for item in manifest.elements(forName: "item") {
          guard let id = item.attribute(forName: "id")?.stringValue,
            let hrefValue = item.attribute(forName: "href")?.stringValue
          else {
            continue
          }

          let resolved = resolveHref(hrefValue, relativeTo: opfDirectory)
          if entryNames.contains(resolved) {
            continue
          }

          if let match = normalizedEntryMap[normalizedPath(resolved)] {
            let updatedHref = relativeHref(for: match, base: opfDirectory)
            if updatedHref != hrefValue {
              item.attribute(forName: "href")?.stringValue = updatedHref
              fixed = true
            }
            continue
          }

          item.detach()
          removedIDs.insert(id)
          fixed = true
        }

        if !removedIDs.isEmpty, let spine = packageElement.elements(forName: "spine").first {
          for itemref in spine.elements(forName: "itemref") {
            guard let idref = itemref.attribute(forName: "idref")?.stringValue else { continue }
            if removedIDs.contains(idref) {
              itemref.detach()
              fixed = true
            }
          }
        }

        return fixed
      }

      ensureMimetypeIsFirstStored()
      ensureContainerExists()

      // Attempt to repair OPF if possible
      if let containerEntry = entries.first(where: { $0.name == "META-INF/container.xml" }) {
        let opfFixed = ensureValidOPF(containerData: containerEntry.data, entries: &entries)
        if opfFixed {
          fixed = true
        }
      }

      archive.entries = entries

      guard fixed else {
        try? fileManager.removeItem(at: backupURL)
        return RepairResult(
          success: false, message: "No repairable issues found", fixed: false, fileURL: url)
      }

      let tempURL = url.appendingPathExtension("repair.tmp")
      defer { try? fileManager.removeItem(at: tempURL) }
      try archive.write(to: tempURL)

      try fileManager.removeItem(at: url)
      try fileManager.moveItem(at: tempURL, to: url)

      if await validator.validate(url: url, as: .epub).isValid {
        try? fileManager.removeItem(at: backupURL)
        return RepairResult(
          success: true, message: "EPUB repaired successfully", fixed: true, fileURL: url)
      }

      try? restoreBackup(from: backupURL, to: url)
      return RepairResult(
        success: false, message: "Repair attempted but file still invalid", fixed: false,
        fileURL: url)
    } catch {
      try? restoreBackup(from: backupURL, to: url)
      return RepairResult(
        success: false, message: "Failed to repair EPUB: \(error.localizedDescription)",
        fixed: false, fileURL: url)
    }
  }

  private func repairPDF(at url: URL) async -> RepairResult {
    let validation = await validator.validate(url: url, as: .pdf)
    guard !validation.isValid else {
      return RepairResult(
        success: true, message: "File is already valid, no repair needed", fixed: false,
        fileURL: url)
    }

    guard var data = try? Data(contentsOf: url) else {
      return RepairResult(
        success: false, message: "Failed to read file", fixed: false, fileURL: url)
    }

    guard data.starts(with: Data("%PDF-".utf8)) else {
      return RepairResult(
        success: false, message: "Missing PDF header, cannot repair", fixed: false, fileURL: url)
    }

    guard data.count >= 5 else {
      return RepairResult(
        success: false, message: "File too small to repair", fixed: false, fileURL: url)
    }

    let tail = data.suffix(1024)
    guard String(data: tail, encoding: .ascii)?.contains("%%EOF") == false else {
      return RepairResult(
        success: false, message: "No repairable issues found", fixed: false, fileURL: url)
    }

    let backupURL = url.appendingPathExtension("backup")
    do {
      try copyFile(from: url, to: backupURL)
    } catch {
      return RepairResult(
        success: false, message: "Failed to create backup: \(error.localizedDescription)",
        fixed: false, fileURL: url)
    }

    data.append(contentsOf: Array("\n%%EOF\n".utf8))

    do {
      try data.write(to: url)
    } catch {
      try? restoreBackup(from: backupURL, to: url)
      return RepairResult(
        success: false, message: "Failed to write repaired file: \(error.localizedDescription)",
        fixed: false, fileURL: url)
    }

    if await validator.validate(url: url, as: .pdf).isValid {
      try? fileManager.removeItem(at: backupURL)
      return RepairResult(
        success: true, message: "PDF repaired successfully (added EOF marker)", fixed: true,
        fileURL: url)
    } else {
      try? restoreBackup(from: backupURL, to: url)
      return RepairResult(
        success: false, message: "Adding EOF marker didn't fix the file", fixed: false, fileURL: url
      )
    }
  }

  private func repairMOBI(at url: URL) async -> RepairResult {
    let validation = await validator.validate(url: url, as: .mobi)
    guard !validation.isValid else {
      return RepairResult(
        success: true, message: "File is already valid, no repair needed", fixed: false,
        fileURL: url)
    }

    guard (try? Data(contentsOf: url).count) ?? 0 >= 68 else {
      return RepairResult(
        success: false, message: "File too small to repair", fixed: false, fileURL: url)
    }

    return RepairResult(
      success: false,
      message:
        "MOBI/AZW3 format is too complex for automatic repair. Consider using Calibre's convert function.",
      fixed: false,
      fileURL: url
    )
  }

  private func copyFile(from source: URL, to destination: URL) throws {
    if fileManager.fileExists(atPath: destination.path) {
      try fileManager.removeItem(at: destination)
    }
    try fileManager.copyItem(at: source, to: destination)
  }

  private func restoreBackup(from backup: URL, to original: URL) throws {
    if fileManager.fileExists(atPath: original.path) {
      try fileManager.removeItem(at: original)
    }
    try fileManager.moveItem(at: backup, to: original)
  }

  private static let defaultContainerXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
      <rootfiles>
        <rootfile full-path="content.opf" media-type="application/oebps-package+xml"/>
      </rootfiles>
    </container>
    """
}
// swiftlint:enable type_body_length
