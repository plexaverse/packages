## 0.2.0

Real-input engine, a production-grade runner, and CI. Pre-1.0, so some APIs
changed; highlights below.

**Interaction (breaking behavior change)**
- `tap` now dispatches hit-tested pointer events via `GestureBinding` instead of
  invoking widget callbacks directly. Covered / `IgnorePointer` / disabled
  widgets are reported not actionable rather than falsely passing.
- `enterText` drives the real IME pipeline (`inputFormatters`, `onChanged`,
  selection, and optional `submit`) instead of assigning `controller.text`.
- Every action runs an actionability loop (exists → enabled → visible →
  receives events) until a timeout, throwing the most specific reason.
- `pumpAndSettle` waits for frames to actually settle (param `duration` →
  `timeout`); `scrollUntilVisible` supports `axis`, prefers the scrollable
  containing the target, and animates instead of jumping.

**Finders** — `textContaining` (substring/RegExp), `byWidget<T>()` (subtypes),
`byTooltip`, and `first`/`last`/`at(n)`; fixed the `byText` RichText
double-match.

**Assertions** — all auto-retry now; added `hidden`, `count`, `enabled`,
`disabled`, `textContaining`, and `SoftAssertions`. `visible` checks real
visibility; `text` descends into children.

**Runner** — new `TestRunner` core with `beforeAll`/`afterAll`/`beforeEach`/
`afterEach` hooks, per-test timeouts, retries + flaky detection, and tag/grep
filtering. The inspector and headless controller now share it.

**Errors** — typed hierarchy under `AutomationException`.

**Reports & screenshots** — `TestReportFormatter` (JSON/JUnit/HTML). Screenshots
are captured automatically on failure and attached to the result (embedded in
the HTML report); `TestArtifactWriter` (via `package:automation/io.dart`) writes
reports + a PNG per failed test to disk. `AutomationScreenshot.capture()` for
manual capture.

**CI** — `example/integration_test` headless entrypoint (exit-code gated) and a
reference GitHub Actions workflow.

**Safety** — `AutomationConfig` disables actuation in release builds by default;
`verboseLogging` gates diagnostics.

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
