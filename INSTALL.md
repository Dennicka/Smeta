# INSTALL (macOS local build)

## 0) Что должно быть установлено на Mac

### Обязательное
- macOS 12+.
- Xcode 15+.
- Command Line Tools for Xcode.

### Проверка (копируйте команды по очереди)
```bash
sw_vers
```
```bash
xcodebuild -version
```
```bash
xcode-select -p
```
```bash
swift --version
```

### Если чего-то нет
1. Установите Xcode из App Store.
2. Откройте Xcode один раз и примите лицензию.
3. В Terminal выполните:
```bash
xcode-select --install
```
4. Если `xcode-select -p` всё ещё не показывает путь:
```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

---

## 1) Сборка приложения (.app)

Откройте Terminal, перейдите в папку проекта и выполните:
```bash
cd /путь/к/Smeta
./Scripts/macos_build.sh
```

После успешной сборки приложение будет здесь:
`release/Smeta.app`

---

## 2) Запуск приложения

Вариант A (как обычное macOS-приложение):
```bash
open release/Smeta.app
```

Вариант B (из Terminal):
```bash
./release/Smeta.app/Contents/MacOS/SmetaApp
```

---

## 3) Smoke-проверка запуска

```bash
cd /путь/к/Smeta
SMETA_ENABLE_RUNTIME_UI_SMOKE=1 ./Scripts/macos_smoke_check.sh
```

Важно:
- Скрипт запускается только на macOS (`uname -s` должен быть `Darwin`).
- Без `SMETA_ENABLE_RUNTIME_UI_SMOKE=1` скрипт завершится с ошибкой.
- По умолчанию проверяется `release/Smeta.app` (можно передать путь к `.app` первым аргументом).
- Для UI smoke automation может требоваться Accessibility permission для процесса Terminal/shell.
- Если в выводе есть `BLOCKED` / `classification=accessibility_permission_required`, выдайте accessibility access для Terminal/shell и повторите запуск.

Ожидаемый успешный результат:
- В конце вывода есть строка `==> PASS: canonical runtime smoke requires operational interactivity`.

Логи smoke-проверки сохраняются в:
- `release/smoke-logs/runtime-operational.log`
- `release/smoke-logs/runtime-controlled-failure.log`
- `release/smoke-logs/runtime-negative.log`
- `release/smoke-logs/runtime-driver.log`

---

## 4) Упаковка в .dmg (опционально)

```bash
cd /путь/к/Smeta
./Scripts/macos_package_dmg.sh
```

Готовый образ:
`release/Smeta.dmg`

---

## 5) Где искать логи, если что-то сломалось

- Лог сборки:  
  `release/build-logs/swift-build-release.log`
- Логи smoke-запуска:  
  `release/smoke-logs/runtime-operational.log`  
  `release/smoke-logs/runtime-controlled-failure.log`  
  `release/smoke-logs/runtime-negative.log`  
  `release/smoke-logs/runtime-driver.log`

Если приложение не открывается через Finder, запустите из Terminal:
```bash
./release/Smeta.app/Contents/MacOS/SmetaApp
```
и приложите текст ошибки из Terminal.
