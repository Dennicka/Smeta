# IMPORT / EXPORT (Stage 5)

- CSV import поддержан для clients, materials, suppliers, supplier articles/prices.
- Каждый импорт проходит через preview + validation, затем create/update.
- Ошибки возвращаются со строкой и полем.
- Экспорт проекта создаёт bundle-папку с `invoice_register.csv` и `manifest.json`.
- Bundle содержит timestamp, app/schema version и список файлов.
