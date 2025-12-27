import Foundation

public struct EPUBMetadataRepairer: @unchecked Sendable {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func repair(at url: URL) throws -> RepairResult {
        guard url.pathExtension.lowercased() == "epub" else {
            return RepairResult(success: false, message: "Not an EPUB file", fixed: false, fileURL: url)
        }

        let backupURL = url.deletingPathExtension().appendingPathExtension("backup.epub")
        if !fileManager.fileExists(atPath: backupURL.path) {
            try copyFile(from: url, to: backupURL)
        }

        do {
            var archive = try ZipArchive.load(from: url)
            guard let containerEntry = entry(named: "META-INF/container.xml", in: archive.entries) else {
                return RepairResult(success: false, message: "Missing container.xml", fixed: false, fileURL: url)
            }

            guard let opfPath = extractOPFPath(from: containerEntry.data) else {
                return RepairResult(success: false, message: "Unable to locate OPF path", fixed: false, fileURL: url)
            }

            guard let opfIndex = archive.entries.firstIndex(where: { $0.name.caseInsensitiveCompare(opfPath) == .orderedSame }) else {
                return RepairResult(success: false, message: "Missing OPF file at \(opfPath)", fixed: false, fileURL: url)
            }

            let opfData = archive.entries[opfIndex].data
            let fallbackTitle = url.deletingPathExtension().lastPathComponent
            let (updatedData, changed) = try repairOPFMetadata(opfData: opfData, fallbackTitle: fallbackTitle)

            guard changed else {
                return RepairResult(success: true, message: "No metadata updates needed", fixed: false, fileURL: url)
            }

            archive.entries[opfIndex].data = updatedData

            let tempURL = url.appendingPathExtension("metadata.tmp")
            defer { try? fileManager.removeItem(at: tempURL) }
            try archive.write(to: tempURL)

            try fileManager.removeItem(at: url)
            try fileManager.moveItem(at: tempURL, to: url)

            return RepairResult(success: true, message: "EPUB metadata repaired", fixed: true, fileURL: url)
        } catch {
            try? restoreBackup(from: backupURL, to: url)
            return RepairResult(success: false, message: "Failed to repair metadata: \(error.localizedDescription)", fixed: false, fileURL: url)
        }
    }

    private func entry(named name: String, in entries: [ZipEntry]) -> ZipEntry? {
        entries.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    private func extractOPFPath(from containerData: Data) -> String? {
        guard let doc = try? XMLDocument(data: containerData, options: []),
              let root = doc.rootElement() else {
            return nil
        }

        let containerNS = root.namespace(forPrefix: "")?.stringValue
        let rootfiles: XMLElement?
        if let containerNS {
            rootfiles = root.elements(forLocalName: "rootfiles", uri: containerNS).first
        } else {
            rootfiles = root.elements(forName: "rootfiles").first
        }
        let rootfile: XMLElement?
        if let containerNS {
            rootfile = rootfiles?.elements(forLocalName: "rootfile", uri: containerNS).first
        } else {
            rootfile = rootfiles?.elements(forName: "rootfile").first
        }
        return rootfile?.attribute(forName: "full-path")?.stringValue
    }

    private func repairOPFMetadata(opfData: Data, fallbackTitle: String) throws -> (Data, Bool) {
        let doc = try XMLDocument(data: opfData, options: [])
        guard let package = doc.rootElement() else {
            return (opfData, false)
        }

        let opfNamespace = package.namespace(forPrefix: "")?.stringValue
        let dcNamespace = "http://purl.org/dc/elements/1.1/"

        let metadata = findOrCreateMetadata(in: package, opfNamespace: opfNamespace)
        ensureDublinCoreNamespace(on: metadata, dcNamespace: dcNamespace)

        var changed = false

        if ensureDCElement(named: "title", value: fallbackTitle, in: metadata, dcNamespace: dcNamespace) {
            changed = true
        }

        let identifierId = ensureIdentifier(in: metadata, dcNamespace: dcNamespace)
        if let identifierId {
            if package.attribute(forName: "unique-identifier")?.stringValue == nil {
                package.addAttribute(XMLNode.attribute(withName: "unique-identifier", stringValue: identifierId) as! XMLNode)
                changed = true
            }
        }

        if ensureDCElement(named: "language", value: "en", in: metadata, dcNamespace: dcNamespace) {
            changed = true
        }

        if normalizeDateElements(in: metadata, dcNamespace: dcNamespace) {
            changed = true
        }

        if ensureModifiedMeta(in: metadata) {
            changed = true
        }

        guard changed else {
            return (opfData, false)
        }

        doc.characterEncoding = "UTF-8"
        doc.version = "1.0"
        let xmlData = Data(doc.xmlString(options: [.nodePrettyPrint]).utf8)
        return (xmlData, true)
    }

    private func findOrCreateMetadata(in package: XMLElement, opfNamespace: String?) -> XMLElement {
        if let metadata = package.elements(forLocalName: "metadata", uri: opfNamespace).first {
            return metadata
        }

        let metadata = XMLElement(name: "metadata")
        if let manifest = package.elements(forLocalName: "manifest", uri: opfNamespace).first,
           let index = package.children?.firstIndex(of: manifest) {
            package.insertChild(metadata, at: index)
        } else {
            package.addChild(metadata)
        }

        return metadata
    }

    private func ensureDublinCoreNamespace(on metadata: XMLElement, dcNamespace: String) {
        let existing = metadata.namespace(forPrefix: "dc")?.stringValue
        if existing == nil {
            let namespace = XMLNode.namespace(withName: "dc", stringValue: dcNamespace) as! XMLNode
            metadata.addNamespace(namespace)
        }
    }

    private func ensureDCElement(named localName: String, value: String, in metadata: XMLElement, dcNamespace: String) -> Bool {
        if let existing = metadata.elements(forLocalName: localName, uri: dcNamespace).first,
           let text = existing.stringValue,
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }

        let element = XMLElement(name: "dc:\(localName)", stringValue: value)
        metadata.addChild(element)
        return true
    }

    private func ensureIdentifier(in metadata: XMLElement, dcNamespace: String) -> String? {
        if let identifier = metadata.elements(forLocalName: "identifier", uri: dcNamespace).first {
            if identifier.attribute(forName: "id") == nil {
                identifier.addAttribute(XMLNode.attribute(withName: "id", stringValue: "BookId") as! XMLNode)
                return "BookId"
            }
            return identifier.attribute(forName: "id")?.stringValue
        }

        let identifierValue = UUID().uuidString
        let identifier = XMLElement(name: "dc:identifier", stringValue: identifierValue)
        identifier.addAttribute(XMLNode.attribute(withName: "id", stringValue: "BookId") as! XMLNode)
        metadata.addChild(identifier)
        return "BookId"
    }

    private func normalizeDateElements(in metadata: XMLElement, dcNamespace: String) -> Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let isoFormatter = ISO8601DateFormatter()
        let today = dateFormatter.string(from: Date())

        var changed = false
        for element in metadata.elements(forLocalName: "date", uri: dcNamespace) {
            guard let value = element.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                element.stringValue = today
                changed = true
                continue
            }

            if isoFormatter.date(from: value) == nil && dateFormatter.date(from: value) == nil {
                element.stringValue = today
                changed = true
            }
        }

        return changed
    }

    private func ensureModifiedMeta(in metadata: XMLElement) -> Bool {
        let modifiedNodes = metadata.elements(forName: "meta").filter { node in
            node.attribute(forName: "property")?.stringValue == "dcterms:modified"
        }

        if let existing = modifiedNodes.first,
           let value = existing.stringValue,
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        let modified = XMLElement(name: "meta", stringValue: isoFormatter.string(from: Date()))
        modified.addAttribute(XMLNode.attribute(withName: "property", stringValue: "dcterms:modified") as! XMLNode)
        metadata.addChild(modified)
        return true
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
}
