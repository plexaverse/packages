import 'package:flutter/foundation.dart';

/// Global switch controlling whether the automation engine may actuate the UI.
///
/// Automation drives real input against the live app, so by default it is
/// **enabled outside release builds only** (debug and profile). In release
/// builds it is off, so an accidental call cannot drive a shipped app. Teams
/// that intentionally run automation against release builds (e.g. on a device
/// farm) can opt in with [enable].
class AutomationConfig {
  AutomationConfig._();

  static bool _enabled = !kReleaseMode;

  /// When true, the engine emits verbose `debugPrint` diagnostics (scrolling,
  /// scrollable resolution). Off by default to keep logs quiet.
  static bool verboseLogging = false;

  /// Whether automation actions are currently allowed.
  static bool get enabled => _enabled;

  /// Enables automation in any build mode, including release. Use only for
  /// deliberate on-device/CI automation of release builds.
  static void enable() => _enabled = true;

  /// Disables automation regardless of build mode.
  static void disable() => _enabled = false;

  /// Restores the default: enabled everywhere except release builds.
  static void resetToDefault() => _enabled = !kReleaseMode;
}
