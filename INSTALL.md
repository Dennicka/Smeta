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
./Scripts/macos_smoke_check.sh
```

Скрипт проверяет наличие `.app`, запускает приложение на короткое время и сохраняет runtime-лог:
`release/smoke-logs/runtime.log`

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
- Лог smoke-запуска:  
  `release/smoke-logs/runtime.log`

Если приложение не открывается через Finder, запустите из Terminal:
```bash
./release/Smeta.app/Contents/MacOS/SmetaApp
```
и приложите текст ошибки из Terminal.
