---
version: 1
slug: "lib-main-dart"
primary_target: "lib/main.dart"
related_targets: ["lib/ui/workspace_page.dart"]
---

# Windows API workspace

Mode: Operate. Build path: code-led Flutter Windows app. The user's final light blue-gray home and detail images are visual critique references, not raster assets to ship as UI. Their layout and the confirmed shape brief are binding. No new concept round is needed for this specified implementation.

## Scope

Local personal HTTP tool: folders, searchable requests, editable tabs, explicit save with recoverable drafts, real JSON/text requests with query/headers/Bearer auth, cancellable requests, persisted history snapshots and edit/replay. Settings: 30-second default timeout and history clearing. Built-in help. No account, collaboration, cloud sync, branch selector or extra navigation.

## Direction contract

THESIS: A small, readable API workbench where the request and its response stay together. Keep the user's two-item navigation and avoid filling the shell with secondary features.

OWN-WORLD: White work areas, cool gray shell, pale blue selection, cobalt actions, slate text, hairline separators and compact 8px controls. Windows system sans for UI; Consolas for code.

STORY: Create a request, edit it, save it, send it, inspect the response, and reopen an immutable historical snapshot as a new draft. A dirty-tab dot distinguishes edited data from saved data.

FIRST VIEWPORT: At 1440x800, a 52px app header, 76px activity rail, approximately 270px resource sidebar and a full-height main workspace. Top-right settings and bottom-right help only. The empty state has one primary new-request button. Editing shows URL/send above parameters, then a resizable response pane. At 1280x720 the same jobs remain visible without overflow.

FORM: User-pinned three-column developer workspace; seed key: not applicable (explicit reference and confirmed shape). Signature interaction: a historical request becomes a distinct editable draft without overwriting its snapshot. Motion is limited to brief selection/hover feedback and request progress.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Acceptance

Verify local-server request/query/body/header/auth handling, timeout/cancellation/error results, save/restart/draft recovery, immutable replay, persistence failures, unsaved-tab and native-window close handling, keyboard save/send, and desktop renders at 1440x800 and 1280x720. No HTML/CSS detector applies to native Dart UI. Do not ship invented successful responses or seeded requests as real user data.
