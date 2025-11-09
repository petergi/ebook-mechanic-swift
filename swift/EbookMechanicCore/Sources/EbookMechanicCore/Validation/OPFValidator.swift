import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// Validates OPF (Open Packaging Format) documents within EPUB files.
struct OPFValidator {

    struct ValidationIssue {
        let severity: Severity
        let message: String

        enum Severity {
            case error      // Critical issues that break EPUB spec
            case warning    // Non-critical issues that should be fixed
            case info       // Informational observations
        }
    }

    struct OPFValidationResult {
        let isValid: Bool
        let issues: [ValidationIssue]
        let opfPath: String?

        var errorMessages: [String] {
            issues.filter { $0.severity == .error }.map { $0.message }
        }

        var warningMessages: [String] {
            issues.filter { $0.severity == .warning }.map { $0.message }
        }
    }

    /// Validates the OPF document and its references within the archive
    func validate(archive: ZipArchive, containerData: Data) -> OPFValidationResult {
        var issues: [ValidationIssue] = []

        // Step 1: Parse container.xml to find OPF path
        guard let opfPath = extractOPFPath(from: containerData) else {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Cannot parse META-INF/container.xml to locate OPF file"
            ))
            return OPFValidationResult(isValid: false, issues: issues, opfPath: nil)
        }

        // Step 2: Check OPF file exists in archive
        guard let opfEntry = archive.entry(named: opfPath) else {
            // Try case-insensitive search
            if let foundEntry = archive.entries.first(where: {
                $0.name.caseInsensitiveCompare(opfPath) == .orderedSame
            }) {
                issues.append(ValidationIssue(
                    severity: .warning,
                    message: "OPF file path case mismatch: container references '\(opfPath)' but found '\(foundEntry.name)'"
                ))
                return validateOPFContent(opfData: foundEntry.data, opfPath: foundEntry.name, archive: archive, issues: &issues)
            }

            issues.append(ValidationIssue(
                severity: .error,
                message: "OPF file not found: \(opfPath)"
            ))
            return OPFValidationResult(isValid: false, issues: issues, opfPath: opfPath)
        }

        // Step 3: Validate OPF content
        return validateOPFContent(opfData: opfEntry.data, opfPath: opfPath, archive: archive, issues: &issues)
    }

    private func validateOPFContent(opfData: Data, opfPath: String, archive: ZipArchive, issues: inout [ValidationIssue]) -> OPFValidationResult {
        // Parse OPF as XML
        guard let document = try? XMLDocument(data: opfData, options: []) else {
            issues.append(ValidationIssue(
                severity: .error,
                message: "OPF file is not valid XML"
            ))
            return OPFValidationResult(isValid: false, issues: issues, opfPath: opfPath)
        }

        guard let packageElement = document.rootElement() else {
            issues.append(ValidationIssue(
                severity: .error,
                message: "OPF file missing root <package> element"
            ))
            return OPFValidationResult(isValid: false, issues: issues, opfPath: opfPath)
        }

        // Validate package element
        validatePackageElement(packageElement, issues: &issues)

        // Validate metadata
        validateMetadata(packageElement: packageElement, issues: &issues)

        // Validate manifest
        let manifestItems = validateManifest(packageElement: packageElement, opfPath: opfPath, archive: archive, issues: &issues)

        // Validate spine
        validateSpine(packageElement: packageElement, manifestItems: manifestItems, issues: &issues)

        // Validate guide (optional but check if present)
        validateGuide(packageElement: packageElement, manifestItems: manifestItems, issues: &issues)

        let hasErrors = issues.contains { $0.severity == .error }
        return OPFValidationResult(isValid: !hasErrors, issues: issues, opfPath: opfPath)
    }

    private func extractOPFPath(from containerData: Data) -> String? {
        guard let document = try? XMLDocument(data: containerData, options: []),
              let root = document.rootElement() else {
            return nil
        }

        // Find <rootfiles><rootfile full-path="..."/>
        let rootfiles = root.elements(forName: "rootfiles").first
        let rootfile = rootfiles?.elements(forName: "rootfile").first
        return rootfile?.attribute(forName: "full-path")?.stringValue
    }

    private func validatePackageElement(_ package: XMLElement, issues: inout [ValidationIssue]) {
        // Check version attribute
        guard let version = package.attribute(forName: "version")?.stringValue else {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Missing required version attribute in <package> element"
            ))
            return
        }

        // Validate version format (should be 2.0 or 3.0)
        if !["2.0", "3.0", "3.1", "3.2"].contains(version) {
            issues.append(ValidationIssue(
                severity: .warning,
                message: "Unusual EPUB version: \(version). Expected 2.0, 3.0, 3.1, or 3.2"
            ))
        }

        // Check unique-identifier attribute
        if package.attribute(forName: "unique-identifier") == nil {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Missing required unique-identifier attribute in <package> element"
            ))
        }
    }

    private func validateMetadata(packageElement: XMLElement, issues: inout [ValidationIssue]) {
        guard let metadata = packageElement.elements(forName: "metadata").first else {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Missing required <metadata> element"
            ))
            return
        }

        // Check for required Dublin Core elements
        let dcNamespace = "http://purl.org/dc/elements/1.1/"
        let titleElements = metadata.elements(forLocalName: "title", uri: dcNamespace)
        if titleElements.isEmpty {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Missing required dc:title element in metadata"
            ))
        }

        let identifierElements = metadata.elements(forLocalName: "identifier", uri: dcNamespace)
        if identifierElements.isEmpty {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Missing required dc:identifier element in metadata"
            ))
        }

        let languageElements = metadata.elements(forLocalName: "language", uri: dcNamespace)
        if languageElements.isEmpty {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Missing required dc:language element in metadata"
            ))
        }

        // Check if unique-identifier points to an actual identifier
        if let uniqueID = packageElement.attribute(forName: "unique-identifier")?.stringValue {
            let hasMatchingID = identifierElements.contains { element in
                element.attribute(forName: "id")?.stringValue == uniqueID
            }
            if !hasMatchingID {
                issues.append(ValidationIssue(
                    severity: .warning,
                    message: "unique-identifier '\(uniqueID)' does not match any dc:identifier id attribute"
                ))
            }
        }
    }

    private func validateManifest(packageElement: XMLElement, opfPath: String, archive: ZipArchive, issues: inout [ValidationIssue]) -> Set<String> {
        guard let manifest = packageElement.elements(forName: "manifest").first else {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Missing required <manifest> element"
            ))
            return []
        }

        let items = manifest.elements(forName: "item")
        if items.isEmpty {
            issues.append(ValidationIssue(
                severity: .warning,
                message: "Manifest is empty - no content items defined"
            ))
            return []
        }

        var itemIDs = Set<String>()
        let opfDirectory = (opfPath as NSString).deletingLastPathComponent

        for item in items {
            guard let id = item.attribute(forName: "id")?.stringValue else {
                issues.append(ValidationIssue(
                    severity: .error,
                    message: "Manifest item missing required id attribute"
                ))
                continue
            }

            // Check for duplicate IDs
            if itemIDs.contains(id) {
                issues.append(ValidationIssue(
                    severity: .error,
                    message: "Duplicate manifest item id: \(id)"
                ))
            }
            itemIDs.insert(id)

            guard let href = item.attribute(forName: "href")?.stringValue else {
                issues.append(ValidationIssue(
                    severity: .error,
                    message: "Manifest item '\(id)' missing required href attribute"
                ))
                continue
            }

            guard let mediaType = item.attribute(forName: "media-type")?.stringValue else {
                issues.append(ValidationIssue(
                    severity: .error,
                    message: "Manifest item '\(id)' missing required media-type attribute"
                ))
                continue
            }

            // Resolve href to absolute path
            let absolutePath = resolveHref(href, relativeTo: opfDirectory)

            // Check if file exists in archive
            if !archive.entries.contains(where: { $0.name == absolutePath }) {
                issues.append(ValidationIssue(
                    severity: .error,
                    message: "Manifest item '\(id)' references missing file: \(href) (resolved to \(absolutePath))"
                ))
            }

            // Validate media type is reasonable
            if mediaType.isEmpty {
                issues.append(ValidationIssue(
                    severity: .error,
                    message: "Manifest item '\(id)' has empty media-type"
                ))
            }
        }

        return itemIDs
    }

    private func validateSpine(packageElement: XMLElement, manifestItems: Set<String>, issues: inout [ValidationIssue]) {
        guard let spine = packageElement.elements(forName: "spine").first else {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Missing required <spine> element"
            ))
            return
        }

        let itemrefs = spine.elements(forName: "itemref")
        if itemrefs.isEmpty {
            issues.append(ValidationIssue(
                severity: .error,
                message: "Spine has no itemref elements - no reading order defined"
            ))
            return
        }

        for itemref in itemrefs {
            guard let idref = itemref.attribute(forName: "idref")?.stringValue else {
                issues.append(ValidationIssue(
                    severity: .error,
                    message: "Spine itemref missing required idref attribute"
                ))
                continue
            }

            // Check that idref points to a manifest item
            if !manifestItems.contains(idref) {
                issues.append(ValidationIssue(
                    severity: .error,
                    message: "Spine itemref references non-existent manifest item: \(idref)"
                ))
            }
        }

        // Check for toc attribute (NCX reference) - required for EPUB 2.0
        if let version = packageElement.attribute(forName: "version")?.stringValue,
           version.hasPrefix("2") {
            if spine.attribute(forName: "toc") == nil {
                issues.append(ValidationIssue(
                    severity: .warning,
                    message: "EPUB 2.0 spine missing 'toc' attribute (NCX reference)"
                ))
            }
        }
    }

    private func validateGuide(packageElement: XMLElement, manifestItems: Set<String>, issues: inout [ValidationIssue]) {
        // Guide is optional, but if present it should be valid
        guard let guide = packageElement.elements(forName: "guide").first else {
            return
        }

        let references = guide.elements(forName: "reference")
        for reference in references {
            guard let type = reference.attribute(forName: "type")?.stringValue else {
                issues.append(ValidationIssue(
                    severity: .warning,
                    message: "Guide reference missing type attribute"
                ))
                continue
            }

            guard let href = reference.attribute(forName: "href")?.stringValue else {
                issues.append(ValidationIssue(
                    severity: .warning,
                    message: "Guide reference '\(type)' missing href attribute"
                ))
                continue
            }

            // Note: We can't easily validate guide hrefs because they can include fragments
            // Just check they're not empty
            if href.isEmpty {
                issues.append(ValidationIssue(
                    severity: .warning,
                    message: "Guide reference '\(type)' has empty href"
                ))
            }
        }
    }

    private func resolveHref(_ href: String, relativeTo base: String) -> String {
        // Remove fragment identifier if present
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
}
