import 'package:flutter/material.dart';
import 'errors.dart';
import 'interaction_engine.dart';

/// Auto-retrying assertions that verify UI state.
///
/// Every assertion polls until it holds or [timeout] elapses, then throws an
/// [AutomationAssertionException] describing the actual state. This mirrors
/// Playwright's web-first assertions: you assert the expected end state and the
/// framework waits for it, instead of you having to sleep first.
class Expect {
  const Expect._();

  static const Duration _defaultTimeout = Duration(seconds: 5);
  static const Duration _pollInterval = Duration(milliseconds: 100);

  static AutomationEngine get _engine => AutomationEngine.instance;

  /// Polls [condition] until it returns true or [timeout] elapses; on timeout
  /// throws an [AutomationAssertionException] built by [failure].
  static Future<void> _waitUntil(
    bool Function() condition,
    Duration timeout,
    String Function() failure,
  ) async {
    final end = DateTime.now().add(timeout);
    while (true) {
      if (condition()) return;
      if (!DateTime.now().isBefore(end)) {
        throw AutomationAssertionException(failure());
      }
      await Future.delayed(_pollInterval);
    }
  }

  /// Asserts [target] is present and actually visible (on-screen, not clipped).
  static Future<void> visible(dynamic target, {Duration timeout = _defaultTimeout}) async {
    final finder = _engine.toFinderPublic(target);
    await _waitUntil(
      () {
        final el = _engine.findFirstElementPublic(finder);
        return el != null && _engine.isVisiblePublic(el);
      },
      timeout,
      () {
        final el = _engine.findFirstElementPublic(finder);
        return el == null
            ? 'Expected $target to be visible, but no matching widget was found within $timeout.'
            : 'Expected $target to be visible, but it was off-screen or clipped after $timeout.';
      },
    );
  }

  /// Asserts [target] becomes hidden: either removed from the tree, or present
  /// but not visible. Waits up to [timeout] for it to disappear.
  static Future<void> hidden(dynamic target, {Duration timeout = _defaultTimeout}) async {
    final finder = _engine.toFinderPublic(target);
    await _waitUntil(
      () {
        final el = _engine.findFirstElementPublic(finder);
        return el == null || !_engine.isVisiblePublic(el);
      },
      timeout,
      () => 'Expected $target to become hidden, but it was still visible after $timeout.',
    );
  }

  /// Asserts [target] is not present in the widget tree. Waits up to [timeout]
  /// for it to be removed.
  static Future<void> absent(dynamic target, {Duration timeout = _defaultTimeout}) async {
    final finder = _engine.toFinderPublic(target);
    await _waitUntil(
      () => _engine.findFirstElementPublic(finder) == null,
      timeout,
      () => 'Expected $target to be absent, but a matching widget was still present after $timeout.',
    );
  }

  /// Asserts exactly [expected] widgets match [target]. Waits up to [timeout].
  static Future<void> count(dynamic target, int expected, {Duration timeout = _defaultTimeout}) async {
    final finder = _engine.toFinderPublic(target);
    await _waitUntil(
      () => _engine.countPublic(finder) == expected,
      timeout,
      () => 'Expected $expected match(es) for $target, but found ${_engine.countPublic(finder)} after $timeout.',
    );
  }

  /// Asserts [target] resolves to an enabled, tappable element.
  static Future<void> enabled(dynamic target, {Duration timeout = _defaultTimeout}) async {
    final finder = _engine.toFinderPublic(target);
    await _waitUntil(
      () => _engine.isTapEnabledPublic(finder),
      timeout,
      () => 'Expected $target to be enabled, but it was disabled or not tappable after $timeout.',
    );
  }

  /// Asserts [target] is present but disabled (no active tap callback).
  static Future<void> disabled(dynamic target, {Duration timeout = _defaultTimeout}) async {
    final finder = _engine.toFinderPublic(target);
    await _waitUntil(
      () {
        final el = _engine.findFirstElementPublic(finder);
        return el != null && !_engine.isTapEnabledPublic(finder);
      },
      timeout,
      () => 'Expected $target to be disabled, but it was enabled or absent after $timeout.',
    );
  }

  /// Asserts [target]'s text equals [expected] exactly. If [target] resolves to
  /// a non-text widget, the first text-bearing descendant is used, so
  /// containers (e.g. a keyed Card) work - not just Text widgets themselves.
  static Future<void> text(dynamic target, String expected, {Duration timeout = _defaultTimeout}) async {
    final finder = _engine.toFinderPublic(target);
    await _waitUntil(
      () {
        final el = _engine.findFirstElementPublic(finder);
        return el != null && _readText(el) == expected;
      },
      timeout,
      () {
        final el = _engine.findFirstElementPublic(finder);
        final actual = el == null ? '<not found>' : (_readText(el) ?? '<no text>');
        return 'Expected $target to have text "$expected", but found "$actual" after $timeout.';
      },
    );
  }

  /// Asserts [target]'s text contains [substring].
  static Future<void> textContaining(dynamic target, String substring, {Duration timeout = _defaultTimeout}) async {
    final finder = _engine.toFinderPublic(target);
    await _waitUntil(
      () {
        final el = _engine.findFirstElementPublic(finder);
        final t = el == null ? null : _readText(el);
        return t != null && t.contains(substring);
      },
      timeout,
      () {
        final el = _engine.findFirstElementPublic(finder);
        final actual = el == null ? '<not found>' : (_readText(el) ?? '<no text>');
        return 'Expected $target to contain "$substring", but found "$actual" after $timeout.';
      },
    );
  }

  /// Reads the text of [element], descending to the first text-bearing
  /// descendant if the element itself carries none.
  static String? _readText(Element element) {
    final direct = _widgetText(element.widget);
    if (direct != null) return direct;

    String? found;
    void visit(Element e) {
      if (found != null) return;
      final t = _widgetText(e.widget);
      if (t != null) {
        found = t;
        return;
      }
      e.visitChildren(visit);
    }

    element.visitChildren(visit);
    return found;
  }

  static String? _widgetText(Widget w) {
    if (w is Text) return w.data;
    if (w is EditableText) return w.controller.text;
    if (w is RichText) return w.text.toPlainText();
    return null;
  }
}

/// Collects assertion failures instead of throwing on the first one.
///
/// Run each assertion through [check]; failures are recorded. Call [assertAll]
/// at the end to fail once with every collected message.
class SoftAssertions {
  final List<String> _failures = [];

  /// The messages of all failed assertions collected so far.
  List<String> get failures => List.unmodifiable(_failures);

  /// Whether any assertion has failed.
  bool get hasFailures => _failures.isNotEmpty;

  /// Runs [assertion], recording its message if it throws an
  /// [AutomationAssertionException]. Other errors propagate.
  Future<void> check(Future<void> Function() assertion) async {
    try {
      await assertion();
    } on AutomationAssertionException catch (e) {
      _failures.add(e.message);
    }
  }

  /// Throws a single [AutomationAssertionException] listing every failure, if
  /// any were collected.
  void assertAll() {
    if (_failures.isEmpty) return;
    throw AutomationAssertionException(
      '${_failures.length} soft assertion(s) failed:\n- ${_failures.join('\n- ')}',
    );
  }
}
