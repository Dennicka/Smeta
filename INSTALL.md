# INSTALL

## Требования
- macOS 12.7 Monterey
- Xcode 15+ (для сборки)

## Установка RC сборки
1. Откройте `release/Smeta.app`.
2. При первом запуске разрешите открытие из System Settings → Privacy & Security.
3. Приложение создаст локальную базу в `~/Library/Application Support/Smeta/smeta.sqlite`.

## Режимы первого запуска
- **Clean**: пустая база, создаёте свои данные.
- **Demo**: база заполняется seed-данными (компания, клиенты, проекты, документы).

## Backup/Restore
Используйте экран **Settings**:
- `Backup базы` — создаёт timestamped backup.
- `Restore базы` — просит подтверждение и проверяет совместимость backup.
