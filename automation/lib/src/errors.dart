/// Typed errors thrown by the automation engine and assertions.
///
/// Catch [AutomationException] to handle any automation failure, or catch a
/// specific subtype to distinguish *why* an action failed. This replaces the
/// previous pattern of throwing raw [Exception]s with human-readable strings
/// that callers had to sniff with `toString().contains(...)`.
library;

/// Base class for every error thrown by this package.
abstract class AutomationException implements Exception {
  /// Human-readable description of what went wrong.
  final String message;

  const AutomationException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// No widget matched the finder (either at all, or within the timeout).
class ElementNotFoundException extends AutomationException {
  const ElementNotFoundException(super.message);
}

/// A condition (existence, visibility, actionability) did not become true
/// before the timeout elapsed.
class AutomationTimeoutException extends AutomationException {
  const AutomationTimeoutException(super.message);
}

/// The widget exists but is not visible: detached, zero-size, off-screen, or
/// clipped away by a viewport/clip.
class NotVisibleException extends AutomationException {
  const NotVisibleException(super.message);
}

/// The widget exists but cannot receive the action: disabled, missing a tap
/// callback, not an editable field, or obscured by another widget so that a
/// real pointer would not reach it.
class NotActionableException extends AutomationException {
  const NotActionableException(super.message);
}

/// The finder matched more than one widget while a single match was required.
///
/// Resolve by making the finder more specific, or by explicitly selecting one
/// match (e.g. `.first`, `.at(n)`).
class AmbiguousMatchException extends AutomationException {
  const AmbiguousMatchException(super.message);
}

/// An [Expect] assertion did not hold.
class AutomationAssertionException extends AutomationException {
  const AutomationAssertionException(super.message);
}

/// An automation action was attempted while automation is disabled (the
/// default in release builds). Opt in with `AutomationConfig.enable()`.
class AutomationDisabledException extends AutomationException {
  const AutomationDisabledException(super.message);
}
