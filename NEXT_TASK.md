# NEXT_TASK

## Следующая инженерная задача (одна)
После выполненного verification pass по Offert/Faktura закрыть остаток D-008: убрать hardcoded/demo document lines и перевести на repository-backed mapping layer документы Avtal, Kreditfaktura, ÄTA и Påminnelse.

## Scope
- Найти demo/hardcoded line generation для `ContractEditorView`, `ExtraWorkView`, `RemindersView` и связанных helper/service path.
- Перевести эти контуры на реальный document/project/estimate state через отдельный builder/mapper (без сборки строк во View).
- При недостатке данных показывать только honest incomplete/empty state, без fake fallback.
- Добавить/расширить автотесты mapping layer для новых типов документов.
- Обновить `CURRENT_STATE.md`, `DEFECT_BACKLOG.md`, `NEXT_TASK.md` по фактическому coverage.

## Out of scope
- Полный rewrite document subsystem.
- macOS runtime/packaging задачи.
- Новый продуктовый функционал.

## Acceptance criteria
1. Avtal/Kreditfaktura/ÄTA/Påminnelse больше не используют hardcoded/demo lines.
2. Все перечисленные типы строятся через repository-backed mapping layer вне View.
3. При пустых/неполных данных нет fake content, есть явный incomplete-state.
4. Есть тесты на mapping/totals для покрытых типов.
5. D-008 может быть переведён в `RESOLVED` только при наличии code evidence по всем типам документов.

## Evidence requirements
- Diff с изменениями только по релевантным document flow файлам + memory files.
- Список команд проверок и их результаты.
- Явный список документов, покрытых фиксом, и документов вне scope.
