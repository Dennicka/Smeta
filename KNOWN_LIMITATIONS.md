# KNOWN_LIMITATIONS

- Полноценный codesign/notarization не выполнен в этой среде (нет Developer ID credentials).
- Автотесты уровня `swift test` не запускаются в Linux-контейнере из-за зависимости на SwiftUI/AppKit.
- Для smoke/UAT сценариев Stage 4 требуется прогон на реальной macOS 12.7 среде.
