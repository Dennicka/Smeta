# NEXT_TASK

## Следующая инженерная задача (одна)
D-007j — провести macOS runtime UX verification для D-007a/D-007c/D-007e/D-007g/D-007g2/D-007g3 (user-facing errors + cancel semantics + orphan-file + safe-overwrite + hard-recovery + post-commit warning semantics).

## Почему именно это next
- D-007a/D-007c/D-007e/D-007g/D-007g2/D-007g3 закрыли code-level silent paths, Offert cancel semantics, orphan-file/half-success semantics, safe-overwrite semantics, hard-recovery semantics и post-commit false-failure semantics, но без macOS UI runtime это остаётся repository-level claim.
- По вашей директиве не уходим в очередной цикл D-010 в Linux-среде без AppKit runtime доступа.

## Scope
Проверить на macOS runtime (SwiftUI/AppKit UI):
- document generation / draft creation / finalize / export;
- import/export (включая cancel-paths диалогов);
- backup/restore (включая cancel/confirm decline);
- project/client/property create-edit-save actions;
- payment / reminder / kreditfaktura related actions;
- critical settings / lifecycle actions.

Для каждого сценария зафиксировать:
- user action;
- induced error/cancel condition;
- фактическое user-facing сообщение (text path);
- отсутствие silent swallow/false-success;
- PASS/FAIL verdict.

## Preconditions
- Нужен реальный macOS runtime доступ (в текущем Linux контейнере это `blocked_env`).
- D-007a/D-007c/D-007e/D-007g/D-007g2/D-007g3 code changes уже внесены, evidence в `EVIDENCE/D007A_ERROR_HANDLING.md`, `EVIDENCE/D007C_OFFERT_CANCEL_SEMANTICS.md`, `EVIDENCE/D007E_ATOMIC_PDF_PERSISTENCE.md`, `EVIDENCE/D007G_SAFE_OVERWRITE_SEMANTICS.md`, `EVIDENCE/D007G2_HARD_RECOVERY_SEMANTICS.md`, `EVIDENCE/D007G3_TEMP_LEAK_AND_POST_COMMIT_SEMANTICS.md`.

## Out of scope
- Новые фичи.
- Рефакторинг вне error-handling UX.
- Повторный Linux-only цикл D-010 E2E без macOS.

## Acceptance criteria
1. Есть coverage map: covered / not covered / blocked по всем критичным цепочкам.
2. В каждом покрытом сценарию ошибка/отмена доходит до пользователя через явный UI-facing message path.
3. Нет silent swallow и false-success как финального поведения в проверенных flow.
4. Обновлены `CURRENT_STATE.md`, `DEFECT_BACKLOG.md`, `NEXT_TASK.md` по фактическим runtime результатам.
