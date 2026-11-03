# Validation evidence

- `flutter analyze`: no issues found.
- `flutter test --dart-define=CAPTURE_UI=true --reporter expanded`: 21 tests passed, including native close protection and storage recovery paths. New header tests verify generated/default values against a real localhost request, case-insensitive custom overrides, disabled-row restoration, non-persistence of generated rows, text colors and retained input focus at both desktop sizes.
- `flutter test integration_test/windows_flow_test.dart -d windows --dart-define=REVIEW_DIR=D:/wealsCode/weils_api/.impeccable/review --reporter expanded`: 1 test passed in a real Windows application using an ephemeral localhost server and temporary storage. Verifies save, real response, history snapshot, independent replay draft and restoration from disk.
- `flutter build windows --release`: succeeded; full runtime directory is `build/windows/x64/runner/Release/`.
- Widget renders: `home-1440.png`, `editor-1440.png`, `editor-1280.png`, `history-1440.png`, `history-1280.png`, `headers-1440.png`, `headers-1280.png`. Fixtures do not ship as default content.
- Native application renders: `native-home.png`, `native-editor.png`, `native-history.png`, captured after dismissing transient snackbars. 1424×821 client area, real local HTTP response.
- Native Dart application: no HTML/CSS detector applies. There are no new runtime raster assets; supplied design PNGs are development references only.

Finish review fix-scoring returned `ship` for its protected-close finding; see `finish-review.md`. This validation file records tests, not a whole-application quality guarantee.
