import Foundation
import EbookMechanicCore

@main
struct RemoveMetadata {
    static func main() {
        let fileURL = URL(fileURLWithPath: "swift/EbookMechanicCore/Tests/Resources/EPUBs/missing-metadata.epub")

        do {
            var archive = try ZipArchive.load(from: fileURL)
            
            guard let containerEntry = archive.entry(named: "META-INF/container.xml") else {
                print("Could not find container.xml")
                exit(1)
            }
            
            let containerXML = try XMLDocument(data: containerEntry.data, options: [])
            let rootFilePath = containerXML.nodes(forXPath: "//@full-path").first?.stringValue
            
            guard let opfPath = rootFilePath, var opfEntry = archive.entry(named: opfPath) else {
                print("Could not find OPF file")
                exit(1)
            }
            
            let opfXML = try XMLDocument(data: opfEntry.data, options: [])
            let metadata = try opfXML.nodes(forXPath: "//metadata").first as? XMLElement
            
            if let metadata = metadata {
                let titleNodes = try metadata.nodes(forXPath: ".//dc:title")
                for node in titleNodes {
                    node.detach()
                }
                
                let languageNodes = try metadata.nodes(forXPath: ".//dc:language")
                for node in languageNodes {
                    node.detach()
                }
                
                opfEntry.data = opfXML.xmlData
                if let index = archive.entries.firstIndex(where: { $0.name == opfPath }) {
                    archive.entries[index] = opfEntry
                }
                
                try archive.write(to: fileURL)
                print("Successfully removed metadata from missing-metadata.epub")
            }
        } catch {
            print("Error: \(error)")
            exit(1)
        }
    }
}
