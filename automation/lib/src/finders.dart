import 'package:flutter/material.dart';

/// Base class for all finders.
///
/// A finder is a reusable query over the element tree. Compose or narrow it
/// with [first], [last], and [at].
abstract class AutomationFinder {
  const AutomationFinder();

  /// Returns all elements matching the finder in the given tree.
  Iterable<Element> findAll(Element root);

  /// Returns the first element matching the finder, or null.
  Element? findFirst(Element root) {
    final matches = findAll(root);
    return matches.isEmpty ? null : matches.first;
  }

  /// Narrows this finder to only its match at [index] (0-based).
  AutomationFinder at(int index) => IndexedFinder(this, index);

  /// Narrows this finder to only its first match.
  AutomationFinder get first => IndexedFinder(this, 0);

  /// Narrows this finder to only its last match.
  AutomationFinder get last => LastFinder(this);
}

/// Helper class to create Finders comfortably.
class Find {
  static const Find instance = Find._();
  const Find._();

  /// Finds widgets by their [Key].
  AutomationFinder byKey(Key key) => KeyFinder(key);

  /// Finds [Text]/[EditableText] widgets whose text equals [text] exactly.
  AutomationFinder byText(String text) => TextFinder(text);

  /// Finds [Text]/[EditableText] widgets whose text contains [pattern].
  ///
  /// [pattern] may be a [String] (substring match) or a [RegExp] (matches
  /// anywhere in the text).
  AutomationFinder textContaining(Pattern pattern) => TextFinder(pattern, mode: TextMatch.contains);

  /// Finds [Icon] widgets with the specific [icon].
  AutomationFinder byIcon(IconData icon) => IconFinder(icon);

  /// Finds widgets whose runtime type is exactly [type].
  ///
  /// This does NOT match subtypes; use [byWidget] for subtype matching.
  AutomationFinder byType(Type type) => TypeFinder(type);

  /// Finds widgets that are of type [T] or any subtype of [T].
  ///
  /// e.g. `find.byWidget<ButtonStyleButton>()` matches `ElevatedButton`,
  /// `TextButton`, etc.
  AutomationFinder byWidget<T extends Widget>() => WidgetTypeFinder<T>();

  /// Finds [Tooltip] widgets whose message equals [message].
  AutomationFinder byTooltip(String message) => TooltipFinder(message);

  /// Finds widgets that contain a specific child.
  AutomationFinder descendant({required AutomationFinder of, required AutomationFinder matching}) {
    return DescendantFinder(ancestor: of, match: matching);
  }
}

/// Global instance for easy access, e.g. `find.byKey(...)`
const Find find = Find.instance;

// --- Shared traversal helper ---

Iterable<Element> _collect(Element root, bool Function(Element) test) {
  final found = <Element>[];
  void visitor(Element element) {
    if (test(element)) found.add(element);
    element.visitChildren(visitor);
  }
  root.visitChildren(visitor);
  return found;
}

// --- Implementations ---

class KeyFinder extends AutomationFinder {
  final Key key;
  const KeyFinder(this.key);

  @override
  Iterable<Element> findAll(Element root) => _collect(root, (e) => e.widget.key == key);

  @override
  String toString() => 'KeyFinder(key: $key)';
}

/// How a [TextFinder] compares the widget text against its pattern.
enum TextMatch { exact, contains }

class TextFinder extends AutomationFinder {
  final Pattern pattern;
  final TextMatch mode;

  const TextFinder(this.pattern, {this.mode = TextMatch.exact});

  bool _matches(String? actual) {
    if (actual == null) return false;
    switch (mode) {
      case TextMatch.exact:
        return actual == pattern;
      case TextMatch.contains:
        return actual.contains(pattern);
    }
  }

  @override
  Iterable<Element> findAll(Element root) {
    // Match Text and EditableText only. We deliberately do NOT match the
    // RichText that a Text builds internally, which previously caused every
    // Text match to also match its child RichText (double counting).
    return _collect(root, (e) {
      final w = e.widget;
      if (w is Text) return _matches(w.data);
      if (w is EditableText) return _matches(w.controller.text);
      return false;
    });
  }

  @override
  String toString() => 'TextFinder(${mode.name}: "$pattern")';
}

class IconFinder extends AutomationFinder {
  final IconData icon;
  const IconFinder(this.icon);

  @override
  Iterable<Element> findAll(Element root) =>
      _collect(root, (e) => e.widget is Icon && (e.widget as Icon).icon == icon);

  @override
  String toString() => 'IconFinder(icon: $icon)';
}

class TypeFinder extends AutomationFinder {
  final Type type;
  const TypeFinder(this.type);

  @override
  Iterable<Element> findAll(Element root) => _collect(root, (e) => e.widget.runtimeType == type);

  @override
  String toString() => 'TypeFinder(type: $type)';
}

class WidgetTypeFinder<T extends Widget> extends AutomationFinder {
  const WidgetTypeFinder();

  @override
  Iterable<Element> findAll(Element root) => _collect(root, (e) => e.widget is T);

  @override
  String toString() => 'WidgetTypeFinder<$T>()';
}

class TooltipFinder extends AutomationFinder {
  final String message;
  const TooltipFinder(this.message);

  @override
  Iterable<Element> findAll(Element root) =>
      _collect(root, (e) => e.widget is Tooltip && (e.widget as Tooltip).message == message);

  @override
  String toString() => 'TooltipFinder(message: "$message")';
}

/// Narrows [parent] to a single match at [index] (0-based).
class IndexedFinder extends AutomationFinder {
  final AutomationFinder parent;
  final int index;
  const IndexedFinder(this.parent, this.index);

  @override
  Iterable<Element> findAll(Element root) {
    final all = parent.findAll(root).toList();
    if (index < 0 || index >= all.length) return const [];
    return [all[index]];
  }

  @override
  String toString() => '$parent.at($index)';
}

/// Narrows [parent] to its last match.
class LastFinder extends AutomationFinder {
  final AutomationFinder parent;
  const LastFinder(this.parent);

  @override
  Iterable<Element> findAll(Element root) {
    final all = parent.findAll(root).toList();
    return all.isEmpty ? const [] : [all.last];
  }

  @override
  String toString() => '$parent.last';
}

class DescendantFinder extends AutomationFinder {
  final AutomationFinder ancestor;
  final AutomationFinder match;

  const DescendantFinder({required this.ancestor, required this.match});

  @override
  Iterable<Element> findAll(Element root) {
    final List<Element> result = [];
    final ancestors = ancestor.findAll(root);
    for (var anc in ancestors) {
      result.addAll(match.findAll(anc));
    }
    return result;
  }

  @override
  String toString() => 'DescendantFinder(of: $ancestor, matches: $match)';
}
