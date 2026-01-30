import 'package:flutter/widgets.dart';

/// Base class for all finders.
abstract class AutomationFinder {
  const AutomationFinder();

  /// Returns all elements matching the finder in the given tree.
  Iterable<Element> findAll(Element root);

  /// Returns the first element matching the finder, or null.
  Element? findFirst(Element root) {
    final matches = findAll(root);
    return matches.isEmpty ? null : matches.first;
  }
}

/// Helper class to create Finders comfortably.
class Find {
  static const Find instance = Find._();
  const Find._();

  /// Finds widgets by their [Key].
  AutomationFinder byKey(Key key) => KeyFinder(key);

  /// Finds [Text] or [RichText] widgets containing [text].
  AutomationFinder byText(String text) => TextFinder(text);

  /// Finds [Icon] widgets with the specific [icon].
  AutomationFinder byIcon(IconData icon) => IconFinder(icon);

  /// Finds widgets of a specific runtime [type].
  AutomationFinder byType(Type type) => TypeFinder(type);
  
  /// Finds widgets that contain a specific child.
  AutomationFinder descendant({required AutomationFinder of, required AutomationFinder matching}) {
    return DescendantFinder(ancestor: of, match: matching);
  }
}

/// Global instance for easy access, e.g. `find.byKey(...)`
const Find find = Find.instance;

// --- Implementations ---

class KeyFinder extends AutomationFinder {
  final Key key;
  const KeyFinder(this.key);

  @override
  Iterable<Element> findAll(Element root) {
    final List<Element> found = [];
    void visitor(Element element) {
      if (element.widget.key == key) {
        found.add(element);
      }
      element.visitChildren(visitor);
    }
    root.visitChildren(visitor);
    return found;
  }
  
  @override
  String toString() => 'KeyFinder(key: $key)';
}

class TextFinder extends AutomationFinder {
  final String text;
  const TextFinder(this.text);

  @override
  Iterable<Element> findAll(Element root) {
    final List<Element> found = [];
    void visitor(Element element) {
      final widget = element.widget;
      if (widget is Text && (widget.data?.contains(text) ?? false)) {
        found.add(element);
      } else if (widget is RichText) {
        // Simple extraction for RichText
        if (widget.text.toPlainText().contains(text)) {
          found.add(element);
        }
      }
      element.visitChildren(visitor);
    }
    root.visitChildren(visitor);
    return found;
  }
   @override
  String toString() => 'TextFinder(text: "$text")';
}

class IconFinder extends AutomationFinder {
  final IconData icon;
  const IconFinder(this.icon);

  @override
  Iterable<Element> findAll(Element root) {
     final List<Element> found = [];
    void visitor(Element element) {
      final widget = element.widget;
      if (widget is Icon && widget.icon == icon) {
        found.add(element);
      }
      element.visitChildren(visitor);
    }
    root.visitChildren(visitor);
    return found;
  }
    @override
  String toString() => 'IconFinder(icon: $icon)';
}

class TypeFinder extends AutomationFinder {
  final Type type;
  const TypeFinder(this.type);

  @override
  Iterable<Element> findAll(Element root) {
    final List<Element> found = [];
    void visitor(Element element) {
      if (element.widget.runtimeType == type) {
        found.add(element);
      }
      element.visitChildren(visitor);
    }
    root.visitChildren(visitor);
    return found;
  }
    @override
  String toString() => 'TypeFinder(type: $type)';
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
