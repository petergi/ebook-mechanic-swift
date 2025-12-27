// swiftlint:disable file_length cyclomatic_complexity large_tuple opening_brace
import Foundation

#if canImport(FoundationXML)
  import FoundationXML
#endif

struct EPUBArchiveNormalizer {
  struct Result {
    var entries: [ZipEntry]
    var containerData: Data
    var opfPath: String
  }

  let defaultContainerXML: String

  func normalize(entries originalEntries: [ZipEntry], containerData: Data?) -> Result {
    var workingEntries = originalEntries.map { entry -> ZipEntry in
      var normalized = entry
      normalized.name = Self.normalizeArchivePath(entry.name)
      normalized.data = Self.normalizeHTMLIfNeeded(for: normalized)
      return normalized
    }

    let initialContainer = containerData ?? Data(defaultContainerXML.utf8)
    var opfPath =
      determineOPFPath(from: initialContainer, entries: workingEntries) ?? "OEBPS/content.opf"
    opfPath = Self.normalizeArchivePath(opfPath)

    if let actual = workingEntries.first(where: {
      $0.name.caseInsensitiveCompare(opfPath) == .orderedSame
    }) {
      opfPath = actual.name
    } else if let foundOPF = workingEntries.first(where: { $0.name.lowercased().hasSuffix(".opf") })
    {
      opfPath = foundOPF.name
    } else {
      let builder = OPFDocumentBuilder(opfPath: opfPath)
      workingEntries.append(
        ZipEntry(name: opfPath, data: builder.buildInitialDocument(), compressionMethod: 8))
    }

    if let index = workingEntries.firstIndex(where: { $0.name == opfPath }) {
      let opfData = workingEntries[index].data
      let normalization = OPFDocumentNormalizer.normalize(
        opfPath: opfPath, opfData: opfData, entries: workingEntries)
      workingEntries = normalization.entries
      if let updatedIndex = workingEntries.firstIndex(where: { $0.name == normalization.opfPath }) {
        workingEntries[updatedIndex].data = normalization.opfData
        opfPath = normalization.opfPath
      }
    }

    let normalizedContainer = EPUBArchiveNormalizer.buildContainerXML(fullPath: opfPath)
    return Result(entries: workingEntries, containerData: normalizedContainer, opfPath: opfPath)
  }
}

extension EPUBArchiveNormalizer {
  fileprivate static func normalizeArchivePath(_ name: String) -> String {
    guard !name.isEmpty else { return name }
    var path = name.replacingOccurrences(of: "\\", with: "/")
    while path.contains("//") {
      path = path.replacingOccurrences(of: "//", with: "/")
    }
    while path.hasPrefix("./") {
      path.removeFirst(2)
    }
    if path.hasPrefix("/") {
      path.removeFirst()
    }
    if path.lowercased() == "meta-inf/container.xml" {
      return "META-INF/container.xml"
    }
    return path
  }

  fileprivate static func normalizeHTMLIfNeeded(for entry: ZipEntry) -> Data {
    let lowercased = entry.name.lowercased()
    guard
      lowercased.hasSuffix(".html") || lowercased.hasSuffix(".xhtml")
        || lowercased.hasSuffix(".htm")
    else {
      return entry.data
    }

    guard var content = String(data: entry.data, encoding: .utf8) else {
      return entry.data
    }

    let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
    let requiredTags = ["<!doctype", "<html", "<head", "<body"]
    let missingCriticalTag = requiredTags.contains {
      trimmed.range(of: $0, options: .caseInsensitive) == nil
    }

    if missingCriticalTag {
      let bodyContent = trimmed.isEmpty ? "&nbsp;" : trimmed
      let rewritten = """
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml">
          <head>
            <meta charset="utf-8"/>
            <title></title>
          </head>
          <body>
        \(bodyContent)
          </body>
        </html>
        """
      return Data(rewritten.replacingOccurrences(of: "\r\n", with: "\n").utf8)
    }

    if trimmed.range(of: "<!doctype", options: .caseInsensitive) == nil {
      content = "<!DOCTYPE html>\n" + content
    }

    return Data(content.replacingOccurrences(of: "\r\n", with: "\n").utf8)
  }

  fileprivate func determineOPFPath(from containerData: Data, entries: [ZipEntry]) -> String? {
    guard let parser = ContainerDocument(data: containerData) else {
      return entries.first(where: { $0.name.lowercased().hasSuffix(".opf") })?.name
    }
    if let path = parser.primaryRootFile {
      return path
    }
    return entries.first(where: { $0.name.lowercased().hasSuffix(".opf") })?.name
  }

  fileprivate static func buildContainerXML(fullPath: String) -> Data {
    let normalized = normalizeArchivePath(fullPath)
    let xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
        <rootfiles>
          <rootfile full-path="\(normalized)" media-type="application/oebps-package+xml"/>
        </rootfiles>
      </container>
      """
    return Data(xml.utf8)
  }
}

// MARK: - Container Parsing

private struct ContainerDocument {
  let primaryRootFile: String?

  init?(data: Data) {
    guard let document = try? XMLDocument(data: data, options: [.nodePreserveWhitespace]) else {
      return nil
    }
    guard let root = document.rootElement() else {
      self.primaryRootFile = nil
      return
    }

    let rootfiles =
      root.children?.compactMap { $0 as? XMLElement }.filter {
        $0.localName == "rootfiles" || $0.name == "rootfiles"
      } ?? []

    if let rootfilesElement = rootfiles.first {
      let rootfileElements =
        rootfilesElement.children?.compactMap { $0 as? XMLElement }.filter {
          $0.localName == "rootfile" || $0.name == "rootfile"
        } ?? []
      if let rootfile = rootfileElements.first,
        let attr = rootfile.attribute(forName: "full-path")?.stringValue,
        !attr.isEmpty
      {
        self.primaryRootFile = attr
        return
      }
    }

    self.primaryRootFile = nil
  }
}

// MARK: - OPF Document Normalization

private struct OPFDocumentNormalizer {
  static func normalize(opfPath: String, opfData: Data, entries: [ZipEntry]) -> (
    entries: [ZipEntry], opfData: Data, opfPath: String
  ) {
    var workingEntries = entries

    let document = OPFDocumentBuilder.ensureDocument(data: opfData)
    guard let package = document.rootElement() else {
      return (workingEntries, opfData, opfPath)
    }

    let version = package.attribute(forName: "version")?.stringValue ?? "2.0"
    let metadata =
      package.firstChild(named: "metadata")
      ?? {
        let node = XMLElement(name: "metadata")
        node.addNamespaceSafe(prefix: "dc", uri: "http://purl.org/dc/elements/1.1/")
        package.insertChild(node, at: 0)
        return node
      }()
    let manifest =
      package.firstChild(named: "manifest")
      ?? {
        let node = XMLElement(name: "manifest")
        package.addChild(node)
        return node
      }()
    let spine =
      package.firstChild(named: "spine")
      ?? {
        let node = XMLElement(name: "spine")
        package.addChild(node)
        return node
      }()

    var manifestItems = ManifestInventory.from(manifest: manifest, opfPath: opfPath)
    manifestItems.removeEntriesMissing(in: workingEntries)
    manifestItems.ensureEntries(for: workingEntries)

    manifestItems.sort()
    let htmlIDs = manifestItems.htmlItemIDs
    spine.replaceChildren(with: manifestItems.composeSpine(from: spine, htmlIDs: htmlIDs))

    if needsNCX(version: version) {
      if let tocID = ensureNCX(
        opfPath: opfPath, manifest: &manifestItems, htmlIDs: htmlIDs, metadata: metadata,
        entries: &workingEntries)
      {
        spine.addAttributeIfNeeded(name: "toc", value: tocID)
      }
    }

    manifestItems.sort()
    manifestItems.apply(to: manifest)
    let normalizedData = document.normalizedData()
    return (workingEntries, normalizedData, opfPath)
  }

  private static func needsNCX(version: String) -> Bool {
    guard let major = Double(version.split(separator: ".").first ?? "2") else {
      return true
    }
    return major < 3
  }
}

// MARK: - OPF Document Helpers

private struct OPFDocumentBuilder {
  let opfPath: String

  func buildInitialDocument() -> Data {
    let document = Self.makeBaseDocument()
    return document.normalizedData()
  }

  static func ensureDocument(data: Data) -> XMLDocument {
    if let document = try? XMLDocument(data: data, options: [.nodePreserveWhitespace]) {
      return document
    } else {
      return makeBaseDocument()
    }
  }

  private static func makeBaseDocument() -> XMLDocument {
    let package = XMLElement(name: "package")
    package.addAttributeSafe(name: "version", value: "2.0")
    package.addAttributeSafe(name: "unique-identifier", value: "BookId")
    package.addNamespaceSafe(prefix: "", uri: "http://www.idpf.org/2007/opf")
    package.addNamespaceSafe(prefix: "dc", uri: "http://purl.org/dc/elements/1.1/")

    let metadata = XMLElement(name: "metadata")
    let title = XMLElement(name: "dc:title", stringValue: "Untitled")
    let identifier = XMLElement(name: "dc:identifier", stringValue: UUID().uuidString)
    identifier.addAttributeSafe(name: "id", value: "BookId")
    metadata.addChild(title)
    metadata.addChild(identifier)

    let manifest = XMLElement(name: "manifest")
    let spine = XMLElement(name: "spine")

    package.addChild(metadata)
    package.addChild(manifest)
    package.addChild(spine)

    let document = XMLDocument(rootElement: package)
    document.characterEncoding = "UTF-8"
    document.version = "1.0"
    return document
  }
}

// MARK: - Manifest Inventory

private struct ManifestInventory {
  struct Item {
    var id: String
    var href: String
    var mediaType: String
    var properties: String?
    var element: XMLElement
  }

  var items: [Item]
  let opfPath: String
  var opfDirectory: String {
    let dir = (opfPath as NSString).deletingLastPathComponent
    return dir
  }

  static func from(manifest: XMLElement, opfPath: String) -> ManifestInventory {
    let children = manifest.children?.compactMap { $0 as? XMLElement } ?? []
    let items = children.compactMap { element -> Item? in
      guard let id = element.attribute(forName: "id")?.stringValue, !id.isEmpty,
        let hrefAttr = element.attribute(forName: "href")?.stringValue,
        let mediaType = element.attribute(forName: "media-type")?.stringValue
      else {
        return nil
      }
      let normalizedHref = ManifestInventory.normalizeHref(hrefAttr)
      element.attribute(forName: "href")?.stringValue = normalizedHref
      let properties = element.attribute(forName: "properties")?.stringValue
      return Item(
        id: id, href: normalizedHref, mediaType: mediaType, properties: properties, element: element
      )
    }
    return ManifestInventory(items: items, opfPath: opfPath)
  }

  mutating func removeEntriesMissing(in entries: [ZipEntry]) {
    let archiveNames = Set(entries.map { $0.name })
    let baseDirectory = opfDirectory
    items.removeAll { item in
      let absolute = ManifestInventory.absolutePath(from: item.href, base: baseDirectory)
      return !archiveNames.contains(absolute)
    }
  }

  mutating func ensureEntries(for entries: [ZipEntry]) {
    var usedIDs = Set(items.map { $0.id })
    let archiveNames = entries.map { $0.name }

    for entryName in archiveNames {
      guard ManifestInventory.shouldManifestInclude(entryName: entryName, opfPath: opfPath) else {
        continue
      }
      guard let mediaType = ManifestInventory.mediaType(for: entryName) else {
        continue
      }
      let href = ManifestInventory.relativePath(from: opfDirectory, to: entryName)
      let normalizedHref = ManifestInventory.normalizeHref(href)

      if let index = items.firstIndex(where: { $0.href == normalizedHref }) {
        if items[index].mediaType != mediaType {
          items[index].mediaType = mediaType
          items[index].element.attribute(forName: "media-type")?.stringValue = mediaType
        }
        if items[index].href != normalizedHref {
          items[index].href = normalizedHref
        }
        items[index].element.attribute(forName: "href")?.stringValue = normalizedHref
        continue
      }

      let identifier = ManifestInventory.makeIdentifier(for: entryName, used: &usedIDs)
      let element = XMLElement(name: "item")
      element.addAttributeSafe(name: "id", value: identifier)
      element.addAttributeSafe(name: "href", value: normalizedHref)
      element.addAttributeSafe(name: "media-type", value: mediaType)
      items.append(
        Item(
          id: identifier, href: normalizedHref, mediaType: mediaType, properties: nil,
          element: element))
    }
  }

  mutating func apply(to manifest: XMLElement) {
    manifest.setChildren(items.map { $0.element })
  }

  mutating func sort() {
    items.sort {
      if $0.id == $1.id {
        return $0.href < $1.href
      }
      return $0.id < $1.id
    }
  }

  var htmlItemIDs: [String] {
    items.filter { ManifestInventory.isHTMLMediaType($0.mediaType) }.map { $0.id }
  }

  func composeSpine(from spine: XMLElement, htmlIDs: [String]) -> [XMLNode] {
    var seen = Set<String>()
    var nodes: [XMLNode] = []
    let existing = spine.children?.compactMap { $0 as? XMLElement } ?? []
    for element in existing {
      guard let idref = element.attribute(forName: "idref")?.stringValue,
        htmlIDs.contains(idref),
        !seen.contains(idref)
      else {
        continue
      }
      nodes.append(element)
      seen.insert(idref)
    }

    for id in htmlIDs where !seen.contains(id) {
      let itemref = XMLElement(name: "itemref")
      itemref.addAttributeSafe(name: "idref", value: id)
      nodes.append(itemref)
      seen.insert(id)
    }
    return nodes
  }

  static func shouldManifestInclude(entryName: String, opfPath: String) -> Bool {
    if entryName == opfPath { return false }
    if entryName == "META-INF/container.xml" { return false }
    if entryName.uppercased().hasPrefix("META-INF/") {
      return false
    }
    return true
  }

  static func makeIdentifier(for entryName: String, used: inout Set<String>) -> String {
    let baseName = ((entryName as NSString).lastPathComponent as NSString).deletingPathExtension
    var candidate = baseName.replacingOccurrences(
      of: "[^A-Za-z0-9]+", with: "-", options: .regularExpression)
    if candidate.isEmpty {
      candidate = "item"
    }
    var suffix = 1
    var identifier = candidate
    while used.contains(identifier) {
      suffix += 1
      identifier = "\(candidate)-\(suffix)"
    }
    used.insert(identifier)
    return identifier
  }

  static func normalizeHref(_ href: String) -> String {
    var cleaned = href.replacingOccurrences(of: "\\", with: "/")
    while cleaned.contains("//") {
      cleaned = cleaned.replacingOccurrences(of: "//", with: "/")
    }
    while cleaned.hasPrefix("./") {
      cleaned.removeFirst(2)
    }
    return cleaned
  }

  static func relativePath(from base: String, to target: String) -> String {
    if base.isEmpty {
      return target
    }
    let baseComponents = base.split(separator: "/")
    let targetComponents = target.split(separator: "/")
    var index = 0
    while index < baseComponents.count && index < targetComponents.count
      && baseComponents[index] == targetComponents[index]
    {
      index += 1
    }
    var relativeComponents: [String] = []
    for _ in index..<baseComponents.count {
      relativeComponents.append("..")
    }
    relativeComponents.append(contentsOf: targetComponents[index...].map(String.init))
    return relativeComponents.joined(separator: "/")
  }

  static func absolutePath(from href: String, base: String) -> String {
    var components = base.split(separator: "/").map(String.init)
    let segments = href.split(separator: "/").map(String.init)
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

  static func mediaType(for entryName: String) -> String? {
    let ext = (entryName as NSString).pathExtension.lowercased()
    switch ext {
    case "html", "htm", "xhtml":
      return "application/xhtml+xml"
    case "css":
      return "text/css"
    case "svg":
      return "image/svg+xml"
    case "jpg", "jpeg":
      return "image/jpeg"
    case "png":
      return "image/png"
    case "gif":
      return "image/gif"
    case "bmp":
      return "image/bmp"
    case "webp":
      return "image/webp"
    case "ttf", "otf":
      return "application/font-sfnt"
    case "woff":
      return "application/font-woff"
    case "woff2":
      return "application/font-woff2"
    case "ncx":
      return "application/x-dtbncx+xml"
    case "opf":
      return "application/oebps-package+xml"
    case "xml":
      return "application/xml"
    case "mp3":
      return "audio/mpeg"
    case "mp4":
      return "video/mp4"
    case "smil":
      return "application/smil+xml"
    default:
      return nil
    }
  }

  static func isHTMLMediaType(_ mediaType: String) -> Bool {
    mediaType == "application/xhtml+xml"
  }
}

// MARK: - NCX Coordinator

extension OPFDocumentNormalizer {
  fileprivate static func ensureNCX(
    opfPath: String, manifest: inout ManifestInventory, htmlIDs: [String], metadata: XMLElement,
    entries: inout [ZipEntry]
  ) -> String? {
    if let existing = manifest.items.first(where: { $0.mediaType == "application/x-dtbncx+xml" }) {
      return existing.id
    }

    let htmlItems = manifest.items.filter { htmlIDs.contains($0.id) }
    guard !htmlItems.isEmpty else { return nil }

    let opfDirectory = manifest.opfDirectory
    let ncxPath = nextAvailableNCXPath(opfDirectory: opfDirectory, entries: entries)
    let href = ManifestInventory.relativePath(from: opfDirectory, to: ncxPath)

    var usedIDs = Set(manifest.items.map { $0.id })
    let id = ManifestInventory.makeIdentifier(for: href, used: &usedIDs)

    let navContent = NCXBuilder.build(
      title: metadata.firstChild(named: "dc:title")?.stringValue ?? "Untitled",
      identifier: metadata.firstChild(named: "dc:identifier")?.stringValue ?? UUID().uuidString,
      htmlItems: htmlItems
    )

    entries.append(ZipEntry(name: ncxPath, data: navContent, compressionMethod: 8))

    let element = XMLElement(name: "item")
    element.addAttributeSafe(name: "id", value: id)
    element.addAttributeSafe(name: "href", value: href)
    element.addAttributeSafe(name: "media-type", value: "application/x-dtbncx+xml")
    manifest.items.append(
      ManifestInventory.Item(
        id: id, href: href, mediaType: "application/x-dtbncx+xml", properties: nil, element: element
      ))

    return id
  }

  fileprivate static func nextAvailableNCXPath(opfDirectory: String, entries: [ZipEntry]) -> String
  {
    var suffix = 0
    let names = Set(entries.map { $0.name.lowercased() })
    while true {
      let file = suffix == 0 ? "toc.ncx" : "toc-\(suffix).ncx"
      let candidate = opfDirectory.isEmpty ? file : "\(opfDirectory)/\(file)"
      if !names.contains(candidate.lowercased()) {
        return candidate
      }
      suffix += 1
    }
  }
}

private struct NCXBuilder {
  static func build(title: String, identifier: String, htmlItems: [ManifestInventory.Item]) -> Data
  {
    var navPoints: [String] = []
    for (index, item) in htmlItems.enumerated() {
      let playOrder = index + 1
      let point = """
            <navPoint id="navPoint-\(playOrder)" playOrder="\(playOrder)">
              <navLabel>
                <text>\(escapeXML(title))</text>
              </navLabel>
              <content src="\(item.href)"/>
            </navPoint>
        """
      navPoints.append(point)
    }

    let xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE ncx PUBLIC "-//NISO//DTD ncx 2005-1//EN" "http://www.daisy.org/z3986/2005/ncx-2005-1.dtd">
      <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
        <head>
          <meta name="dtb:uid" content="\(escapeXML(identifier))"/>
          <meta name="dtb:depth" content="1"/>
          <meta name="dtb:totalPageCount" content="0"/>
          <meta name="dtb:maxPageNumber" content="0"/>
        </head>
        <docTitle>
          <text>\(escapeXML(title))</text>
        </docTitle>
        <navMap>
      \(navPoints.joined(separator: "\n"))
        </navMap>
      </ncx>
      """
    return Data(xml.utf8)
  }

  private static func escapeXML(_ value: String) -> String {
    value
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
  }
}

extension XMLDocument {
  fileprivate func normalizedData() -> Data {
    self.characterEncoding = "UTF-8"
    self.version = "1.0"
    let xmlString = self.xmlString(options: [.nodePrettyPrint])
    return Data(xmlString.replacingOccurrences(of: "\r\n", with: "\n").utf8)
  }
}

extension XMLElement {
  fileprivate func firstChild(named name: String) -> XMLElement? {
    return children?.compactMap { $0 as? XMLElement }.first(where: { element in
      if let fullName = element.name, fullName == name {
        return true
      }
      if let local = element.localName, local == name {
        return true
      }
      if let suffix = name.split(separator: ":").last, let local = element.localName,
        local == suffix
      {
        return true
      }
      return false
    })
  }

  fileprivate func addAttributeIfNeeded(name: String, value: String) {
    if let existing = attribute(forName: name) {
      existing.stringValue = value
    } else {
      addAttributeSafe(name: name, value: value)
    }
  }

  fileprivate func replaceChildren(with nodes: [XMLNode]) {
    setChildren(nodes)
  }

  fileprivate func addAttributeSafe(name: String, value: String) {
    guard let node = XMLNode.attribute(withName: name, stringValue: value) as? XMLNode else {
      return
    }
    addAttribute(node)
  }

  fileprivate func addNamespaceSafe(prefix: String, uri: String) {
    guard let node = XMLNode.namespace(withName: prefix, stringValue: uri) as? XMLNode else {
      return
    }
    addNamespace(node)
  }
}
