# RELEASE_NOTES (Stage 4 RC)

## Stabilization
- Включены SQLite foreign keys/WAL/busy timeout.
- Добавлены индексы и уникальность для document numbering.
- Добавлена валидация restore backup на обязательные таблицы.

## Validation hardening
- Проверки обязательных полей для клиента/объекта/проекта/помещений.
- Проверки draft-документов (пустые строки, отрицательные суммы, B2B reverse charge, ROT только B2C).
- Запрет переплаты относительно `balance_due`.

## UX/операционное
- Показ ошибок/инфо-сообщений в основном layout.
- Фильтрация списка документов по строке поиска.
- Исправлен ввод суммы оплаты: отдельное состояние на каждую faktura.
- В Settings показан путь к данным и кнопка открытия папки.

## Backup/restore
- Timestamped имя backup.
- Подтверждение destructive restore.

## Stage 5 (operational layer)
- Added import/export operational UI, suppliers/purchases storage, repricing/profitability helpers, receivables buckets, lifecycle archive/restore, notes/tags scaffolding, data portability manifest exports, and admin reset tools.
