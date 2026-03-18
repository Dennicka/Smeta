# D-013b Full Schema Parity Evidence Pack

Date (UTC): 2026-03-18

## 1) Exact commands

1. `rg -n "CREATE TABLE IF NOT EXISTS (supplier_contacts|supplier_price_history|material_price_profiles|purchase_lists|purchase_list_items|project_lifecycle_history|project_tags|project_notes|export_logs)" Sources/SmetaApp/Data/SQLiteDatabase.swift`
2. `cat > /tmp/sqlite3.modulemap <<'EOM'\nmodule SQLite3 [system] {\n  header "/usr/include/sqlite3.h"\n  link "sqlite3"\n  export *\n}\nEOM`
3. `swiftc -Xcc -fmodule-map-file=/tmp/sqlite3.modulemap Sources/SmetaApp/Data/SQLiteHelpers.swift Sources/SmetaApp/Data/SQLiteDatabase.swift Scripts/verify_schema_parity_d013b.swift -o /tmp/verify_schema_parity_d013b`
4. `/tmp/verify_schema_parity_d013b`
5. `swiftc -Xcc -fmodule-map-file=/tmp/sqlite3.modulemap Sources/SmetaApp/Data/SQLiteHelpers.swift Sources/SmetaApp/Data/SQLiteDatabase.swift Scripts/verify_migration_flow_d013.swift -o /tmp/verify_migration_flow_d013 && /tmp/verify_migration_flow_d013`

## 2) Full raw outputs

### Command 1 output
```text
586:        CREATE TABLE IF NOT EXISTS supplier_contacts (
596:        CREATE TABLE IF NOT EXISTS supplier_price_history (
604:        CREATE TABLE IF NOT EXISTS material_price_profiles (
613:        CREATE TABLE IF NOT EXISTS purchase_lists (
622:        CREATE TABLE IF NOT EXISTS purchase_list_items (
636:        CREATE TABLE IF NOT EXISTS project_lifecycle_history (
644:        CREATE TABLE IF NOT EXISTS project_tags (
650:        CREATE TABLE IF NOT EXISTS project_notes (
659:        CREATE TABLE IF NOT EXISTS export_logs (
```

### Command 2 output
```text
(no stdout)
```

### Command 3 output
```text
(no stdout)
```

### Command 4 output
```text
[INFO] Scenario A schema version: 3
[INFO] Scenario B schema version: 3
[INFO] Scenario B legacy project name: Legacy Project
[INFO] Scenario B workflow_status after migration: draft
| object name | type | expected | actual in Scenario A | actual in Scenario B |
|---|---|---|---|---|
| schema_migrations | table | yes | yes | yes |
| companies | table | yes | yes | yes |
| clients | table | yes | yes | yes |
| properties | table | yes | yes | yes |
| speed_profiles | table | yes | yes | yes |
| projects | table | yes | yes | yes |
| rooms | table | yes | yes | yes |
| work_catalog | table | yes | yes | yes |
| material_catalog | table | yes | yes | yes |
| estimates | table | yes | yes | yes |
| estimate_lines | table | yes | yes | yes |
| document_templates | table | yes | yes | yes |
| generated_documents | table | yes | yes | yes |
| project_status_history | table | yes | yes | yes |
| document_series | table | yes | yes | yes |
| tax_profiles | table | yes | yes | yes |
| business_documents | table | yes | yes | yes |
| business_document_lines | table | yes | yes | yes |
| document_snapshots | table | yes | yes | yes |
| payments | table | yes | yes | yes |
| payment_allocations | table | yes | yes | yes |
| room_templates | table | yes | yes | yes |
| surfaces | table | yes | yes | yes |
| openings | table | yes | yes | yes |
| trim_elements | table | yes | yes | yes |
| work_categories | table | yes | yes | yes |
| work_subcategories | table | yes | yes | yes |
| material_categories | table | yes | yes | yes |
| material_usage_norms | table | yes | yes | yes |
| work_speed_rules | table | yes | yes | yes |
| complexity_rules | table | yes | yes | yes |
| surface_condition_profiles | table | yes | yes | yes |
| estimate_versions | table | yes | yes | yes |
| estimate_adjustments | table | yes | yes | yes |
| suppliers | table | yes | yes | yes |
| supplier_articles | table | yes | yes | yes |
| equipment_cost_rules | table | yes | yes | yes |
| transport_cost_rules | table | yes | yes | yes |
| waste_disposal_rules | table | yes | yes | yes |
| default_project_presets | table | yes | yes | yes |
| calculation_snapshots | table | yes | yes | yes |
| calculation_rules | table | yes | yes | yes |
| supplier_contacts | table | yes | yes | yes |
| supplier_price_history | table | yes | yes | yes |
| material_price_profiles | table | yes | yes | yes |
| purchase_lists | table | yes | yes | yes |
| purchase_list_items | table | yes | yes | yes |
| project_lifecycle_history | table | yes | yes | yes |
| project_tags | table | yes | yes | yes |
| project_notes | table | yes | yes | yes |
| export_logs | table | yes | yes | yes |
| idx_business_documents_number_unique | index | yes | yes | yes |
| idx_document_series_type_unique | index | yes | yes | yes |
| idx_payment_allocations_document | index | yes | yes | yes |
| idx_projects_updated_lookup | index | yes | yes | yes |
[INFO] Scenario A migration rows: 3
[INFO] Scenario B migration rows: 3
[INFO] Scenario B legacy data preserved: yes
[VERDICT] fresh schema parity = PASS
[VERDICT] legacy upgrade parity = PASS
RESULT: PASS
```

### Command 5 output
```text
[PASS] Scenario A: schema version is 3
[PASS] Scenario A: projects.workflow_status exists
[INFO] Scenario A migration history: 1:001_base_schema, 2:002_legacy_upgrade_bridge, 3:003_stage5_ops_tail_tables
[PASS] Scenario A: ordered migration ids recorded
[PASS] Scenario A: smoke read/write PASS
[PASS] Scenario B: legacy fixture starts without projects.workflow_status
[PASS] Scenario B: migrated schema version is 3
[PASS] Scenario B: legacy project data preserved
[PASS] Scenario B: new required workflow_status default populated
[PASS] Scenario B: new required pricing_mode default populated
[PASS] Scenario C: second runner pass keeps migration history unchanged
[PASS] Scenario C: no duplicate migration rows
[INFO] Scenario B migration history: 1:001_base_schema, 2:002_legacy_upgrade_bridge, 3:003_stage5_ops_tail_tables
RESULT: PASS
```

## 3) Exit codes

- Command 1: `0`
- Command 2: `0`
- Command 3: `0`
- Command 4: `0`
- Command 5: `0`

## 4) Object checklist verdict table

Source of expected set: full release-required schema objects that existed in prior path + migration metadata (`schema_migrations`).

| object name | type (table/index) | expected | actual in Scenario A | actual in Scenario B |
|---|---|---|---|---|
| See full table in Command 4 raw output above (complete list, no omissions). | mixed | yes | all `yes` | all `yes` |

## 5) Final parity verdict

- fresh schema parity = **PASS**
- legacy upgrade parity = **PASS**
- Stage5/ops tail tables (`export_logs`, `project_notes`, `purchase_lists`, `purchase_list_items`, `supplier_contacts`, `supplier_price_history`, `material_price_profiles`, `project_lifecycle_history`, `project_tags`) are present in both scenarios.
