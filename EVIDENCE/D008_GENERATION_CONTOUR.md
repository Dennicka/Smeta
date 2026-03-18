# D-008 Generation Contour Evidence

Date (UTC): 2026-03-18

## 1. Exact commands

1. `rg -n "buildAvtal|buildKreditfaktura|buildAta|buildPaminnelse|createAvtalDraftFromSelectedProject|createKreditfakturaDraftFromSelectedProject|createAtaDraftFromSelectedProject|createPaminnelseDraftFromSelectedProject|createDraftDocument\\(type: \\.ata|createDraftDocument\\(type: \\.paminnelse|ÄTA extra spackling|Påminnelse för \\(" Sources/SmetaApp Sources/SmetaCore Scripts/verify_generation_contour_d008.swift`
2. `swiftc Sources/SmetaCore/Models/Entities.swift Sources/SmetaCore/Services/DocumentDraftBuilder.swift Scripts/verify_generation_contour_d008.swift -o /tmp/verify_generation_contour_d008 && /tmp/verify_generation_contour_d008`

## 2. Full raw outputs

### Command 1 output (generation wiring + removal of old fake entry points)
```text
Scripts/verify_generation_contour_d008.swift:69:        switch builder.buildAvtal(context: context, title: "") {
Scripts/verify_generation_contour_d008.swift:79:        switch builder.buildKreditfaktura(context: context, title: "") {
Scripts/verify_generation_contour_d008.swift:89:        switch builder.buildAta(context: context, title: "") {
Scripts/verify_generation_contour_d008.swift:99:        switch builder.buildPaminnelse(context: context, title: "") {
Scripts/verify_generation_contour_d008.swift:111:        switch builder.buildAvtal(context: missingContext, title: "") {
Scripts/verify_generation_contour_d008.swift:119:        switch builder.buildPaminnelse(context: missingContext, title: "") {
Sources/SmetaApp/ViewModels/AppViewModel.swift:305:    func createAvtalDraftFromSelectedProject() {
Sources/SmetaApp/ViewModels/AppViewModel.swift:312:            switch documentDraftBuilder.buildAvtal(context: context, title: "Avtal \(project.name)") {
Sources/SmetaApp/ViewModels/AppViewModel.swift:325:    func createKreditfakturaDraftFromSelectedProject() {
Sources/SmetaApp/ViewModels/AppViewModel.swift:332:            switch documentDraftBuilder.buildKreditfaktura(context: context, title: "Kreditfaktura \(project.name)") {
Sources/SmetaApp/ViewModels/AppViewModel.swift:345:    func createAtaDraftFromSelectedProject() {
Sources/SmetaApp/ViewModels/AppViewModel.swift:352:            switch documentDraftBuilder.buildAta(context: context, title: "ÄTA \(project.name)") {
Sources/SmetaApp/ViewModels/AppViewModel.swift:365:    func createPaminnelseDraftFromSelectedProject() {
Sources/SmetaApp/ViewModels/AppViewModel.swift:372:            switch documentDraftBuilder.buildPaminnelse(context: context, title: "Påminnelse \(project.name)") {
Sources/SmetaCore/Services/DocumentDraftBuilder.swift:108:    func buildAvtal(
Sources/SmetaCore/Services/DocumentDraftBuilder.swift:143:    func buildKreditfaktura(
Sources/SmetaCore/Services/DocumentDraftBuilder.swift:193:    func buildAta(
Sources/SmetaCore/Services/DocumentDraftBuilder.swift:225:    func buildPaminnelse(
Sources/SmetaApp/Services/DocumentDraftBuilder.swift:108:    func buildAvtal(
Sources/SmetaApp/Services/DocumentDraftBuilder.swift:143:    func buildKreditfaktura(
Sources/SmetaApp/Services/DocumentDraftBuilder.swift:193:    func buildAta(
Sources/SmetaApp/Services/DocumentDraftBuilder.swift:225:    func buildPaminnelse(
Sources/SmetaApp/Views/Stage2Views.swift:33:                vm.createAvtalDraftFromSelectedProject()
Sources/SmetaApp/Views/Stage2Views.swift:97:                vm.createAtaDraftFromSelectedProject()
Sources/SmetaApp/Views/Stage2Views.swift:112:                vm.createPaminnelseDraftFromSelectedProject()
Sources/SmetaApp/Views/Stage2Views.swift:115:                vm.createKreditfakturaDraftFromSelectedProject()
```

### Command 2 output (runtime verification of generation-only contour for 4 document types)
```text
[PASS] avtal: payload type
[PASS] avtal: related finalized offert
[PASS] avtal: lines copied from repository offert
[PASS] kreditfaktura: payload type
[PASS] kreditfaktura: related finalized faktura
[PASS] kreditfaktura: negative lines from faktura
[PASS] ata: payload type
[PASS] ata: lines mapped from estimate
[PASS] ata: source notes mention estimate
[PASS] paminnelse: payload type
[PASS] paminnelse: related invoice id
[PASS] paminnelse: amount from invoice balance
[PASS] avtal: honest incomplete path
[PASS] paminnelse: honest incomplete path
RESULT: PASS
```

## 3. Exit codes

- Command 1: `0`
- Command 2: `0`

## 4. Mapping `document type → proof`

| Document type | Generation source proved | Runtime proof |
|---|---|---|
| Avtal | Repository-backed finalized Offert + repository lines (`relatedDocumentId` + copied line descriptions). | `[PASS] avtal: related finalized offert`, `[PASS] avtal: lines copied from repository offert` |
| Kreditfaktura | Repository-backed finalized Faktura + repository lines (mirrored as negative credit rows). | `[PASS] kreditfaktura: related finalized faktura`, `[PASS] kreditfaktura: negative lines from faktura` |
| ÄTA | Repository-backed estimate lines mapped through `DocumentDraftBuilder.mapEstimateLines`. | `[PASS] ata: lines mapped from estimate` |
| Påminnelse | Repository-backed outstanding Faktura balance (`balanceDue`) with honest missing-data rejection. | `[PASS] paminnelse: amount from invoice balance`, `[PASS] paminnelse: honest incomplete path` |

## 5. PASS / FAIL summary

### PASS
- Generation paths for Avtal/Kreditfaktura/ÄTA/Påminnelse are moved out of view-level manual demo arrays and into `DocumentDraftBuilder` + `AppViewModel` repository-backed context loading.
- All 4 types now return explicit incomplete errors when required source state is missing (no decorative fake fallback).
- Runtime script verifies success and incomplete branches for generation contour without using export pipeline.

### FAIL / BLOCKED_ENV
- No macOS-only UI runtime claim is made here. This evidence is generation/service-level in Linux and does not assert AppKit export behavior.

## 6. Final verdict for D-008

- Based on code + runtime evidence in this task scope: **D-008 = RESOLVED**.
