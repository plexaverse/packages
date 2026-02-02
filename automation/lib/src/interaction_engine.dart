import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'finders.dart';

class AutomationEngine {
  static final AutomationEngine instance = AutomationEngine._();
  AutomationEngine._();

  /// Callback for when an interaction occurs (used for UI highlighting).
  void Function(Offset position)? onInteraction;

  /// Helper to convert dynamic target (Key or Finder) to AutomationFinder
  AutomationFinder _toFinder(dynamic target) {
    if (target is AutomationFinder) return target;
    if (target is Key) return find.byKey(target);
    if (target is String) return find.byText(target);
    if (target is IconData) return find.byIcon(target);
    if (target is Type) return find.byType(target);
    throw ArgumentError('Target must be a Key, String, IconData, Type, or AutomationFinder. Got: ${target.runtimeType}');
  }

  /// Triggers a tap on the widget identified by [target].
  Future<void> tap(dynamic target, {Duration timeout = const Duration(seconds: 5)}) async {
    final finder = _toFinder(target);
    await waitFor(finder, timeout: timeout);

    final element = _findFirstElement(finder);
    if (element == null) throw Exception('Widget not found for $finder');

    // 1. Check if the element itself is tappable
    Element? tappableElement;
    if (_isTappable(element)) {
      tappableElement = element;
    } else {
      // 2. Look UP for a tappable ancestor that has a callback
      element.visitAncestorElements((ancestor) {
        if (_isTappable(ancestor) && _hasTapCallback(ancestor.widget)) {
          tappableElement = ancestor;
          return false; // Stop visiting
        }
        return true;
      });
      
      // 3. If still not found, Look DOWN (legacy behavior)
      if (tappableElement == null) {
        tappableElement = _findFirstDescendant(element, (e) => _isTappable(e) && _isVisible(e) && _hasTapCallback(e.widget));
      }
    }

    final tappable = tappableElement;
    if (tappable == null) {
       throw Exception('Widget found but no tappable ancestor or descendant found: $finder.');
    }
    if (!_isVisible(tappable)) {
       throw Exception('Widget found but not visible: $finder.');
    }

    await _highlightAndTap(tappable);
  }

  Future<void> _highlightAndTap(Element element) async {
    final renderBox = element.renderObject as RenderBox?;
    if (renderBox != null) {
      final position = renderBox.localToGlobal(renderBox.size.center(Offset.zero));
      onInteraction?.call(position);
      await Future.delayed(const Duration(milliseconds: 300));
    }
    
    _triggerTap(element.widget);
  }

  /// Enters text into a TextField identified by [target].
  Future<void> enterText(dynamic target, String text, {Duration timeout = const Duration(seconds: 5)}) async {
    final finder = _toFinder(target);
    await waitFor(finder, timeout: timeout);

    final root = _findFirstElement(finder);
    if (root == null) throw Exception('Widget not found for $finder');

    // Find the EditableText descendant.
    final editableElement = _findFirstDescendant(root, (e) => e.widget is EditableText && _isVisible(e));
    
    final editable = editableElement;
    if (editable == null) throw Exception('No EditableText widget found inside $finder. Ensure you are targeting a TextField or TextFormField.');

    await _highlightAndEnterText(editable, text);
  }

  Future<void> _highlightAndEnterText(Element element, String text) async {
     final renderBox = element.renderObject as RenderBox?;
    if (renderBox != null) {
      final position = renderBox.localToGlobal(renderBox.size.center(Offset.zero));
      onInteraction?.call(position);
      await Future.delayed(const Duration(milliseconds: 300));
    }
    
    final widget = element.widget as EditableText;
    widget.controller.text = text;
    widget.onChanged?.call(text);
  }

  /// Scrolls until the [target] is visible.
  Future<void> scrollUntilVisible(dynamic target, {
    dynamic scrollable,
    double step = 300.0, 
    int maxScrolls = 60, 
    Duration duration = const Duration(milliseconds: 100)
  }) async {
    final targetFinder = _toFinder(target);
    
    debugPrint('[Automation] scrollUntilVisible: looking for $targetFinder');

    final existingElement = _findFirstElement(targetFinder);
    if (existingElement != null) {
      debugPrint('[Automation] Found element: ${existingElement.widget.runtimeType}');
      final visible = _isVisible(existingElement);
      debugPrint('[Automation] Is visible: $visible');
      if (visible) {
        debugPrint('[Automation] target already visible');
        return;
      }
    } else {
      debugPrint('[Automation] Element not found in tree, will scroll to find it');
    }

    ScrollableState? scrollState;
    if (scrollable != null) {
      final scrollableFinder = _toFinder(scrollable);
      final element = _findFirstElement(scrollableFinder);
      if (element != null) {
        scrollState = Scrollable.of(element);
      }
    } else {
      // Find the "best" vertical scrollable (the one with the largest scroll extent)
      debugPrint('[Automation] Looking for scrollable widgets in tree...');
      ScrollableState? bestScrollable;
      double largestExtent = -1.0;
      int elementCount = 0;

      void visitor(Element e) {
        elementCount++;
        // Skip only the overlay part of the automation inspector, not the wrapper
        final widgetTypeName = e.widget.runtimeType.toString();
        if (widgetTypeName == 'AutomationInspectorOverlay' || 
            widgetTypeName == '_AutomationInspectorOverlayState' ||
            widgetTypeName.startsWith('_AutomationInspector')) {
          return; // Skip this subtree
        }

        final widgetType = e.widget.runtimeType.toString();
        // Log potential scrollable-related widgets
        if (widgetType.contains('Scroll') || widgetType.contains('List') || widgetType.contains('View')) {
          debugPrint('[Automation] Checking widget: $widgetType');
        }

        if (e.widget is Scrollable) {
          debugPrint('[Automation] Found Scrollable widget: ${e.widget.runtimeType}');
          
          if (e is StatefulElement) {
            final state = e.state;
            if (state is ScrollableState) {
              debugPrint('[Automation] Scrollable axis: ${state.widget.axis}');
              if (state.widget.axis == Axis.vertical) {
                try {
                  if (state.position.hasPixels) {
                    final extent = state.position.maxScrollExtent;
                    debugPrint('[Automation] Scrollable maxExtent: $extent');
                    if (extent > largestExtent) {
                      largestExtent = extent;
                      bestScrollable = state;
                    }
                  }
                } catch (err) {
                  debugPrint('[Automation] Error getting scroll extent: $err');
                }
              }
            }
          }
        }
        e.visitChildren(visitor);
      }
      WidgetsBinding.instance.rootElement?.visitChildren(visitor);
      debugPrint('[Automation] Visited $elementCount elements, bestScrollable: ${bestScrollable != null}');
      scrollState = bestScrollable;
    }
    
    if (scrollState == null) {
      throw Exception('No vertical Scrollable found to perform scrollUntilVisible.');
    }

    final position = scrollState.position;
    debugPrint('[Automation] Using scrollable with maxExtent: ${position.maxScrollExtent}');
    
    for (int i = 0; i < maxScrolls; i++) {
        final element = _findFirstElement(targetFinder);
        if (element != null && _isVisible(element)) {
           debugPrint('[Automation] Target found in tree and visible. Ensuring visibility...');
           await Scrollable.ensureVisible(element, duration: const Duration(milliseconds: 200), alignment: 0.5);
           await Future.delayed(const Duration(milliseconds: 300)); // Wait for animation
           return;
        }
        
        if (position.pixels >= position.maxScrollExtent) {
           debugPrint('[Automation] Reached bottom of scrollable at ${position.pixels}');
           break;
        }

        final targetScroll = (position.pixels + step).clamp(0.0, position.maxScrollExtent);
        debugPrint('[Automation] Jumping to $targetScroll (Step $i)');
        position.jumpTo(targetScroll);
        
        await Future.delayed(duration);
        await Future.delayed(const Duration(milliseconds: 50));
    }
    
    if (!_elementExistsAndVisible(targetFinder)) {
      throw Exception('Could not find $target after scrolling to the bottom (${position.maxScrollExtent}px).');
    }
  }

  // --- Finders & Utils ---

  Element? _findFirstElement(AutomationFinder finder) {
    if (WidgetsBinding.instance.rootElement == null) return null;
    final root = WidgetsBinding.instance.rootElement!;
    
    // We search the entire tree recursively.
    return finder.findFirst(root);
  }
  
  bool _elementExistsAndVisible(AutomationFinder finder) {
    final element = _findFirstElement(finder);
    if (element == null) return false;
    return _isVisible(element);
  }

  Future<void> waitFor(dynamic target, {Duration timeout = const Duration(seconds: 5)}) async {
    final finder = _toFinder(target);
    final endTime = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(endTime)) {
      if (_findFirstElement(finder) != null) return;
      await Future.delayed(const Duration(milliseconds: 200));
    }
    throw Exception('Timed out waiting for $finder');
  }

  bool _isTappable(Element element) {
    final widget = element.widget;
    return widget is ButtonStyleButton || 
           widget is MaterialButton ||
           widget is FloatingActionButton ||
           widget is IconButton ||
           widget is InkWell ||
           widget is InkResponse ||
           widget is GestureDetector ||
           widget is ListTile;
  }

  /// Checks if a tappable widget actually has a tap callback set.
  bool _hasTapCallback(Widget widget) {
    if (widget is ButtonStyleButton) return widget.onPressed != null;
    if (widget is MaterialButton) return widget.onPressed != null;
    if (widget is FloatingActionButton) return widget.onPressed != null;
    if (widget is IconButton) return widget.onPressed != null;
    if (widget is InkWell) return widget.onTap != null;
    if (widget is InkResponse) return widget.onTap != null;
    if (widget is GestureDetector) return widget.onTap != null;
    if (widget is ListTile) return widget.onTap != null;
    return false;
  }

  void _triggerTap(Widget widget) {
    bool tapped = false;
    
    if (widget is ButtonStyleButton) {
      if (widget.onPressed != null) { widget.onPressed!(); tapped = true; }
    } else if (widget is MaterialButton) {
      if (widget.onPressed != null) { widget.onPressed!(); tapped = true; }
    } else if (widget is FloatingActionButton) {
      if (widget.onPressed != null) { widget.onPressed!(); tapped = true; }
    } else if (widget is IconButton) {
      if (widget.onPressed != null) { widget.onPressed!(); tapped = true; }
    } else if (widget is InkWell) {
      if (widget.onTap != null) { widget.onTap!(); tapped = true; }
    } else if (widget is InkResponse) {
      if (widget.onTap != null) { widget.onTap!(); tapped = true; }
    } else if (widget is GestureDetector) {
      if (widget.onTap != null) { widget.onTap!(); tapped = true; }
    } else if (widget is ListTile) {
      if (widget.onTap != null) { widget.onTap!(); tapped = true; }
    }
    
    if (!tapped) {
       throw Exception('Failed to tap ${widget.runtimeType}: onPressed/onTap is null or widget type handled incorrectly.');
    }
  }

  bool _isVisible(Element element) {
    final renderBox = element.renderObject as RenderBox?;
    if (renderBox == null || !renderBox.attached || !renderBox.hasSize || renderBox.size.isEmpty) return false;

    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final windowSize = view.physicalSize / view.devicePixelRatio;
    Rect visibleArea = Rect.fromLTWH(0, 0, windowSize.width, windowSize.height);

    // Initial widget rect in global coords
    final pos = renderBox.localToGlobal(Offset.zero);
    final widgetRect = pos & renderBox.size;

    // Check if it's even on the screen generally
    if (!visibleArea.overlaps(widgetRect)) return false;

    // CLIP CHECK: Walk up the tree and intersect with all viewports
    RenderObject? ancestor = renderBox.parent as RenderObject?;
    while (ancestor != null) {
      if (ancestor is RenderViewportBase) {
        final Rect viewportGlobalRect = (ancestor as RenderBox).localToGlobal(Offset.zero) & (ancestor as RenderBox).size;
        visibleArea = visibleArea.intersect(viewportGlobalRect);
      } else if (ancestor is RenderBox) {
        // Handle explicit clipping widgets if possible, 
        // though Viewport is the primary concern for lists.
      }
      ancestor = ancestor.parent;
    }

    // Now check if the widget significantly overlaps the final visible area.
    // We use a small threshold or center point to be sure it's actually "seeable"
    return visibleArea.overlaps(widgetRect);
  }
  
  Element? _findFirstDescendant(Element element, bool Function(Element) predicate) {
    if (predicate(element)) return element;
    Element? found;
    void visitor(Element child) {
      if (found != null) return;
      if (predicate(child)) {
        found = child;
      } else {
        child.visitChildren(visitor);
      }
    }
    element.visitChildren(visitor);
    return found;
  }
    
  // --- Public Headers for internal libraries (like Expect) ---
  
  AutomationFinder toFinderPublic(dynamic target) => _toFinder(target);
  
  Element? findFirstElementPublic(AutomationFinder finder) => _findFirstElement(finder);
  
  bool isVisiblePublic(Element element) => _isVisible(element);

  Future<void> pumpAndSettle({Duration duration = const Duration(milliseconds: 500)}) async {
    await Future.delayed(duration);
  }
}
