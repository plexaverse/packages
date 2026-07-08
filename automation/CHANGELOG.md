## 0.1.0

Packaging, correctness, and honesty pass.

- Add an MIT license (previously a `TODO` placeholder).
- Fix package metadata: real description, `topics`, declared platforms
  (`android`, `ios`), and a corrected `flutter` SDK lower bound (`>=3.24.0`).
- Stop shipping ad-hoc analyzer dumps (`lib/src/analysis.txt`,
  `analysis_final.txt`) and ignore them going forward.
- Resolve all `flutter analyze` issues.
- **Fix:** `Expect.visible` now verifies the widget is actually visible
  (present, sized, on-screen, not clipped by a scroll viewport) instead of
  only checking that it exists in the tree.
- **Fix:** tapping a disabled control now returns a clear "widget is disabled"
  error and lets `tap()` fall through to an enabled ancestor/descendant,
  instead of failing with a confusing internal error.
- Correct README claims about CI/headless support and `Expect.visible`.

## 0.0.1+1

- Added comprehensive README documentation.
- Documented core components: `AutomationInspectorWrapper`,
  `AutomationRegistry`, and `AutomationEngine`.
- Provided setup and usage guides.
