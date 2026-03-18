# D012 Defect Fix 8b — residual money-impacting literals closure

Date: 2026-03-18 (UTC)

## Commands, raw outputs, exit codes

### 1) Residual literals grep in active calculation/document-draft paths
Command:
```bash
rg -n "0\\.01|0\\.1|0\\.2|0\\.25|reverseCharge \\? 0" Sources/SmetaApp/Services/EstimateCalculator.swift Sources/SmetaApp/ViewModels/AppViewModel.swift Sources/SmetaApp/Services/DocumentDraftBuilder.swift Sources/SmetaCore/Services/DocumentDraftBuilder.swift
```
Exit code: `1`
Raw output:
```text
```

### 2) Rules storage grep (defaults now centralized in persisted rules source)
Command:
```bash
rg -n "0\\.01|0\\.1|0\\.2|0\\.25" Sources/SmetaApp/Models/Entities.swift Sources/SmetaApp/Data/SQLiteDatabase.swift Sources/SmetaApp/Repositories/AppRepository.swift
```
Exit code: `0`
Raw output:
```text
Sources/SmetaApp/Repositories/AppRepository.swift:23:        _ = try insertWorkItem(WorkCatalogItem(id: 0, name: "Покраска стен", unit: "м²", baseRatePerUnitHour: 0.22, basePrice: 220, swedishName: "Målning av väggar", sortOrder: 0))
Sources/SmetaApp/Models/Entities.swift:94:    var slopeArea: Double { 2 * (width + height) * 0.15 * Double(count) }
Sources/SmetaApp/Models/Entities.swift:331:        marginPercent: 0.12,
Sources/SmetaApp/Models/Entities.swift:332:        momsPercent: 0.25,
Sources/SmetaApp/Models/Entities.swift:333:        minSpeedRate: 0.01,
Sources/SmetaApp/Models/Entities.swift:334:        minWorkMediumSpeed: 0.1,
Sources/SmetaApp/Models/Entities.swift:335:        minWorkBaseRatePerUnitHour: 0.01,
Sources/SmetaApp/Models/Entities.swift:336:        minSpeedDaysDivider: 0.1,
Sources/SmetaApp/Models/Entities.swift:337:        minMaterialUsagePerWorkUnit: 0.2,
Sources/SmetaApp/Models/Entities.swift:338:        minMaterialQuantity: 0.01
Sources/SmetaApp/Data/SQLiteDatabase.swift:417:            margin_percent REAL NOT NULL DEFAULT 0.12,
Sources/SmetaApp/Data/SQLiteDatabase.swift:418:            moms_percent REAL NOT NULL DEFAULT 0.25,
Sources/SmetaApp/Data/SQLiteDatabase.swift:419:            min_speed_rate REAL NOT NULL DEFAULT 0.01,
Sources/SmetaApp/Data/SQLiteDatabase.swift:420:            min_work_medium_speed REAL NOT NULL DEFAULT 0.1,
Sources/SmetaApp/Data/SQLiteDatabase.swift:421:            min_work_base_rate_per_unit_hour REAL NOT NULL DEFAULT 0.01,
Sources/SmetaApp/Data/SQLiteDatabase.swift:422:            min_speed_days_divider REAL NOT NULL DEFAULT 0.1,
Sources/SmetaApp/Data/SQLiteDatabase.swift:423:            min_material_usage_per_work_unit REAL NOT NULL DEFAULT 0.2,
Sources/SmetaApp/Data/SQLiteDatabase.swift:424:            min_material_quantity REAL NOT NULL DEFAULT 0.01
Sources/SmetaApp/Data/SQLiteDatabase.swift:443:        ) VALUES (1, 0.02, 0.03, 0.04, 0.12, 0.25, 0.01, 0.1, 0.01, 0.1, 0.2, 0.01);
Sources/SmetaApp/Data/SQLiteDatabase.swift:493:        try? execute("ALTER TABLE calculation_rules ADD COLUMN min_speed_rate REAL NOT NULL DEFAULT 0.01;")
Sources/SmetaApp/Data/SQLiteDatabase.swift:494:        try? execute("ALTER TABLE calculation_rules ADD COLUMN min_work_medium_speed REAL NOT NULL DEFAULT 0.1;")
Sources/SmetaApp/Data/SQLiteDatabase.swift:495:        try? execute("ALTER TABLE calculation_rules ADD COLUMN min_work_base_rate_per_unit_hour REAL NOT NULL DEFAULT 0.01;")
Sources/SmetaApp/Data/SQLiteDatabase.swift:496:        try? execute("ALTER TABLE calculation_rules ADD COLUMN min_speed_days_divider REAL NOT NULL DEFAULT 0.1;")
Sources/SmetaApp/Data/SQLiteDatabase.swift:497:        try? execute("ALTER TABLE calculation_rules ADD COLUMN min_material_usage_per_work_unit REAL NOT NULL DEFAULT 0.2;")
Sources/SmetaApp/Data/SQLiteDatabase.swift:498:        try? execute("ALTER TABLE calculation_rules ADD COLUMN min_material_quantity REAL NOT NULL DEFAULT 0.01;")
```

### 3) Runtime evidence: every `CalculationRules` field affects result
Command:
```bash
swiftc Sources/SmetaApp/Models/Entities.swift Sources/SmetaApp/Services/EstimateCalculator.swift Scripts/verify_calculation_rules_d012.swift -o /tmp/verify_calculation_rules_d012 && /tmp/verify_calculation_rules_d012
```
Exit code: `0`
Raw output:
```text
[PASS] transportPercent affects transportCost
[PASS] equipmentPercent affects equipmentCost
[PASS] wastePercent affects wasteCost
[PASS] marginPercent affects margin
[PASS] momsPercent affects moms
[PASS] minSpeedRate affects labor in low-speed scenario
[PASS] minWorkMediumSpeed affects labor when configured threshold exceeds work.mediumSpeed
[PASS] minWorkBaseRatePerUnitHour affects labor when baseRatePerUnitHour is zero
[PASS] minSpeedDaysDivider affects day estimate
[PASS] minMaterialUsagePerWorkUnit affects material cost when usagePerWorkUnit is zero
[PASS] minMaterialQuantity affects material cost floor
[PASS] grand total changes after rule tuning
BASELINE_TOTAL=6176.8000
BASELINE_LABOR=4000.0000
BASELINE_MATERIALS=200.0000
RESULT: PASS
```

### 4) Runtime evidence: VAT no longer uses hidden 0.25 fallback
Command:
```bash
swiftc Sources/SmetaCore/Models/Entities.swift Sources/SmetaCore/Services/DocumentDraftBuilder.swift Scripts/verify_document_draft_builder.swift -o /tmp/verify_document_draft_builder && /tmp/verify_document_draft_builder
```
Exit code: `0`
Raw output:
```text
VERIFY_DOCUMENT_DRAFT_BUILDER: PASS
```

### 5) Optional broader test run (known env limitation)
Command:
```bash
swift test --filter DocumentDraftBuilderTests
```
Exit code: `1`
Raw output (trimmed to relevant error):
```text
error: no such module 'SQLite3'
...
error: fatalError
```

## Literal classification table

| literal | location | classification | evidence |
|---|---|---|---|
| `0.01` | `CalculationRules.minSpeedRate` / `minWorkBaseRatePerUnitHour` / `minMaterialQuantity` defaults | rule | Command #3 shows changing each related rule changes labor/material totals. |
| `0.1` | `CalculationRules.minWorkMediumSpeed` / `minSpeedDaysDivider` defaults | rule | Command #3 shows changing each related rule changes labor/day totals. |
| `0.2` | `CalculationRules.minMaterialUsagePerWorkUnit` default | rule | Command #3 shows changing this rule changes material totals. |
| `0.25` | `CalculationRules.momsPercent` default and tax profile `vatRate` values in persisted settings tables | rule | Command #4 proves VAT in document draft path is profile-driven (changed profile changes VAT amount in script assertions). |

## Result for D-012 scope

- Residual literals `0.01/0.1/0.2` were moved from inline calculator code to persisted `calculation_rules` fields.
- Stage2 VAT path no longer has a hardcoded fallback `0.25`; it resolves VAT from persisted `tax_profiles` in both `AppViewModel.createDraftDocument(...)` and `DocumentDraftBuilder`.
- Runtime evidence confirms each extracted rule affects relevant monetary/result fields.
