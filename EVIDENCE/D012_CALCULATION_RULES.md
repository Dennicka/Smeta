# D-012 Calculation Rules Evidence

Date (UTC): 2026-03-18

## 1. Exact commands

1. `rg -n "transport = \(labor + materials\) \* 0\.02|equipment = labor \* 0\.03|waste = materials \* 0\.04|margin = subtotal \* 0\.12|moms = \(subtotal + margin\) \* 0\.25" Sources/SmetaApp/Services/EstimateCalculator.swift`
2. `rg -n "CalculationRules|calculation_rules|rules\.transportPercent|rules\.equipmentPercent|rules\.wastePercent|rules\.marginPercent|rules\.momsPercent|repository\.calculationRules\(\)" Sources/SmetaApp/Models/Entities.swift Sources/SmetaApp/Data/SQLiteDatabase.swift Sources/SmetaApp/Repositories/AppRepository.swift Sources/SmetaApp/ViewModels/AppViewModel.swift Sources/SmetaApp/Services/EstimateCalculator.swift`
3. `rg -n "max\(0\.01|max\(material\.usagePerWorkUnit, 0\.2\)|/ 100|vatRate = taxMode == \.reverseCharge \? 0 : 0\.25" Sources/SmetaApp/Services/EstimateCalculator.swift Sources/SmetaApp/ViewModels/AppViewModel.swift`
4. `swiftc Sources/SmetaApp/Models/Entities.swift Sources/SmetaApp/Services/EstimateCalculator.swift Scripts/verify_calculation_rules_d012.swift -o /tmp/verify_calculation_rules_d012 && /tmp/verify_calculation_rules_d012`

## 2. Full raw outputs

### Command 1 output (old hardcoded percentages removed from calculation totals path)
```text
(no matches)
```

### Command 2 output (single source-of-truth wiring)
```text
Sources/SmetaApp/Services/EstimateCalculator.swift:43:                   rules: CalculationRules) -> CalculationResult {
Sources/SmetaApp/Services/EstimateCalculator.swift:97:        let transport = (labor + materials) * rules.transportPercent
Sources/SmetaApp/Services/EstimateCalculator.swift:98:        let equipment = labor * rules.equipmentPercent
Sources/SmetaApp/Services/EstimateCalculator.swift:99:        let waste = materials * rules.wastePercent
Sources/SmetaApp/Services/EstimateCalculator.swift:101:        let margin = subtotal * rules.marginPercent
Sources/SmetaApp/Services/EstimateCalculator.swift:102:        let moms = (subtotal + margin) * rules.momsPercent
Sources/SmetaApp/ViewModels/AppViewModel.swift:36:    @Published var calculationRules: CalculationRules = .default
Sources/SmetaApp/ViewModels/AppViewModel.swift:96:        calculationRules = try repository.calculationRules()
Sources/SmetaApp/Data/SQLiteDatabase.swift:412:        CREATE TABLE IF NOT EXISTS calculation_rules (
Sources/SmetaApp/Data/SQLiteDatabase.swift:424:        INSERT OR IGNORE INTO calculation_rules (
Sources/SmetaApp/Models/Entities.swift:312:struct CalculationRules: PersistableEntity {
Sources/SmetaApp/Models/Entities.swift:320:    static let `default` = CalculationRules(
Sources/SmetaApp/Repositories/AppRepository.swift:101:    func calculationRules() throws -> CalculationRules {
Sources/SmetaApp/Repositories/AppRepository.swift:102:        if let row = try fetch("SELECT id,transport_percent,equipment_percent,waste_percent,margin_percent,moms_percent FROM calculation_rules WHERE id=1 LIMIT 1", { s in
Sources/SmetaApp/Repositories/AppRepository.swift:103:            CalculationRules(id: sqlite3_column_int64(s, 0),
Sources/SmetaApp/Repositories/AppRepository.swift:112:        try upsertCalculationRules(.default)
Sources/SmetaApp/Repositories/AppRepository.swift:116:    func upsertCalculationRules(_ rules: CalculationRules) throws {
Sources/SmetaApp/Repositories/AppRepository.swift:118:        INSERT INTO calculation_rules (id,transport_percent,equipment_percent,waste_percent,margin_percent,moms_percent)
Sources/SmetaApp/Repositories/AppRepository.swift:127:            sqlite3_bind_double(s, 1, rules.transportPercent)
Sources/SmetaApp/Repositories/AppRepository.swift:128:            sqlite3_bind_double(s, 2, rules.equipmentPercent)
Sources/SmetaApp/Repositories/AppRepository.swift:129:            sqlite3_bind_double(s, 3, rules.wastePercent)
Sources/SmetaApp/Repositories/AppRepository.swift:130:            sqlite3_bind_double(s, 4, rules.marginPercent)
Sources/SmetaApp/Repositories/AppRepository.swift:131:            sqlite3_bind_double(s, 5, rules.momsPercent)
```

### Command 3 output (honest remainder still hardcoded)
```text
Sources/SmetaApp/Services/EstimateCalculator.swift:54:                let speedRate = max(0.01, speed.coefficient * max(work.mediumSpeed > 0 ? work.mediumSpeed : 1, 0.1))
Sources/SmetaApp/Services/EstimateCalculator.swift:76:                let quantity = max(0.01, room.area * max(material.usagePerWorkUnit, 0.2))
Sources/SmetaApp/Services/EstimateCalculator.swift:77:                let materialCost = quantity * (material.basePrice + material.basePrice * material.markupPercent / 100)
Sources/SmetaApp/ViewModels/AppViewModel.swift:249:            let vatRate = taxMode == .reverseCharge ? 0 : 0.25
```

### Command 4 output (runtime value change affects result)
```text
[PASS] baseline transport uses default 2% rule
[PASS] baseline equipment uses default 3% rule
[PASS] baseline waste uses default 4% rule
[PASS] baseline margin uses default 12% rule
[PASS] baseline moms uses default 25% rule
[PASS] baseline grand total is stable
[PASS] tuned transport uses new 10% rule
[PASS] tuned equipment uses new 15% rule
[PASS] tuned waste uses new 20% rule
[PASS] tuned margin uses new 30% rule
[PASS] tuned moms uses new 10% rule
[PASS] tuned grand total changed after rule update
[PASS] grand total differs between default and tuned rules
BASELINE_TOTAL=7364.00
BASELINE_TRANSPORT=100.00
TUNED_TOTAL=9009.00
TUNED_TRANSPORT=500.00
RESULT: PASS
```

## 3. Exit codes

- Command 1: `1` (expected `rg` no-match result; confirms old literals are absent)
- Command 2: `0`
- Command 3: `0`
- Command 4: `0`

## 4. Before/after evidence

- Before (legacy behavior): calculation totals path used inline literals `0.02 / 0.03 / 0.04 / 0.12 / 0.25` directly in `EstimateCalculator`.
- After (current behavior): the same totals now read from `CalculationRules` loaded from persistent table `calculation_rules` and propagated through `AppViewModel -> EstimateCalculator`.
- Runtime confirmation: changing rule values from default to tuned profile changes final output (`7364.00 -> 9009.00`).

## 5. Honest verdict for D-012

- Closed part: transport/equipment/waste/margin/moms percentages are no longer hardcoded in estimate totals path.
- Remaining part: other money-impacting numeric guardrails are still hardcoded (`0.01`, `0.1`, `0.2` in `EstimateCalculator`) and Stage2 document VAT fallback (`0.25`) still exists outside this rule source.
- Therefore status is updated to **PARTIAL**, not `RESOLVED`.
