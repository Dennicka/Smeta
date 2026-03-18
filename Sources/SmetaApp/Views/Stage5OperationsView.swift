import SwiftUI
import AppKit

struct Stage5OperationsView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var csvText: String = "name,email,phone,address\n"
    @State private var noteText: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Stage 5 — Operational layer").font(.largeTitle).bold()

                GroupBox("Import / Export") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CSV import clients (preview+validation in service)")
                        TextEditor(text: $csvText)
                            .frame(height: 120)
                            .font(.system(.body, design: .monospaced))
                        HStack {
                            Button("Импорт clients CSV") { vm.importClientsFromCSV(raw: csvText) }
                            if let project = vm.selectedProject {
                                Button("Export project bundle") { vm.exportProjectBundle(projectId: project.id) }
                            }
                        }
                    }
                }

                GroupBox("Profitability / Receivables") {
                    VStack(alignment: .leading, spacing: 8) {
                        if let project = vm.selectedProject {
                            Button("Refresh profitability") { vm.refreshProjectProfitability(projectId: project.id) }
                        }
                        if let p = vm.selectedProjectProfitability {
                            Text("Planned margin: \(p.plannedGrossMargin, specifier: "%.2f")")
                            Text("Invoiced / Paid / Outstanding: \(p.actualInvoicedAmount, specifier: "%.2f") / \(p.paidAmount, specifier: "%.2f") / \(p.outstandingAmount, specifier: "%.2f")")
                            Text("Expected ROT claim: \(p.expectedROTClaimAmount, specifier: "%.2f")")
                        }
                        ForEach(Array(vm.receivableBuckets.enumerated()), id: \.offset) { _, bucket in
                            Text("\(bucket.title): \(bucket.documents.count) / \(bucket.totalOutstanding, specifier: "%.2f")")
                                .font(.caption)
                        }
                    }
                }

                GroupBox("Lifecycle + Notes") {
                    VStack(alignment: .leading, spacing: 8) {
                        if let project = vm.selectedProject {
                            HStack {
                                Button("Archive project") { vm.archiveProject(project.id) }
                                Button("Restore project") { vm.restoreProjectFromArchive(project.id) }
                            }
                            HStack {
                                TextField("Internal note", text: $noteText)
                                Button("Add note") {
                                    guard !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                                    vm.addInternalNote(projectId: project.id, type: "internal", text: noteText, pinned: false)
                                    noteText = ""
                                }
                            }
                        }
                        ForEach(vm.projectNotes) { note in
                            Text("• [\(note.noteType)] \(note.text)").font(.caption)
                        }
                    }
                }
            }
        }
    }
}
