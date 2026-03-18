# NEXT_TASK

## Следующая инженерная задача (одна)
D-015 — очистка release/archive состояния от build/output noise перед финализацией релизного пакета.

## Scope
- Зафиксировать deterministic clean-release checklist (что разрешено в артефактах, что обязательно удаляется).
- Добавить/обновить verify-команду, которая проверяет чистоту release/archive состояния перед фиксацией.
- Синхронизировать критерий чистоты в `DEFECT_BACKLOG.md` и релизных заметках.

## Out of scope
- Любые новые фичи или изменения бизнес-логики.
- Попытка закрыть macOS-only runtime задачи (`D-001..D-003`, D-002 AppKit e2e).
- Повторная ревизия D-014 (уже закрыт и задокументирован).

## Acceptance criteria
1. Есть явный allowlist/denylist release-артефактов.
2. Есть воспроизводимая verify-команда с raw output и exit code.
3. `DEFECT_BACKLOG.md` и связанные release-docs согласованы по новому правилу clean-release.

## Evidence requirements
- Exact commands + raw outputs + exit codes.
- Отдельный evidence-файл по D-015 clean-release pass.
