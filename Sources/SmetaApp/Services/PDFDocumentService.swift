#if canImport(AppKit)
import Foundation
import AppKit

final class PDFDocumentService {
    func generateOffertSwedish(template: DocumentTemplate,
                               company: Company,
                               client: Client,
                               project: Project,
                               result: CalculationResult,
                               saveURL: URL) throws {
        let text = """
        \(template.headerText)

        Företag: \(company.name)
        Organisationsnummer: \(company.orgNumber)
        Kund: \(client.name)
        Projekt: \(project.name)

        Totala timmar: \(String(format: "%.2f", result.totalHours))
        Totala dagar: \(String(format: "%.2f", result.totalDays))
        Arbetskostnad: \(String(format: "%.2f", result.totalLabor)) SEK
        Materialkostnad: \(String(format: "%.2f", result.totalMaterials)) SEK
        Totalpris: \(String(format: "%.2f", result.grandTotal)) SEK

        \(template.footerText)
        """

        let attributed = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 13)])
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 595, height: 842))
        textView.textStorage?.setAttributedString(attributed)
        let pdfData = textView.dataWithPDF(inside: textView.bounds)
        try pdfData.write(to: saveURL)
    }

    func generateBusinessDocumentPDF(title: String, body: String, saveURL: URL) throws {
        let attributed = NSAttributedString(string: "\(title)

\(body)", attributes: [.font: NSFont.systemFont(ofSize: 13)])
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 595, height: 842))
        textView.textStorage?.setAttributedString(attributed)
        let pdfData = textView.dataWithPDF(inside: textView.bounds)
        try pdfData.write(to: saveURL)
    }

}
#endif
