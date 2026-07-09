import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide find;
import 'package:in_app_automation/in_app_automation.dart';

void main() {
  bool visible(String text) {
    final el = AutomationEngine.instance.findFirstElementPublic(find.byText(text));
    return el != null && AutomationEngine.instance.isVisiblePublic(el);
  }

  testWidgets('a plain on-screen Text is visible', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('hi'))));
    expect(visible('hi'), isTrue);
  });

  testWidgets('Offstage content is not visible', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Offstage(offstage: true, child: Text('ghost'))),
    ));
    expect(visible('ghost'), isFalse);
  });

  testWidgets('Opacity 0 content is not visible; Opacity 1 is', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(children: [
          Opacity(opacity: 0, child: Text('faded')),
          Opacity(opacity: 1, child: Text('solid')),
        ]),
      ),
    ));
    expect(visible('faded'), isFalse);
    expect(visible('solid'), isTrue);
  });

  testWidgets('content pushed outside a ClipRect is not visible', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: ClipRect(
            child: SizedBox(
              width: 50,
              height: 50,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Positioned far to the right, outside the 50x50 clip.
                  Positioned(left: 300, top: 0, child: Text('clipped')),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
    expect(visible('clipped'), isFalse);
  });
}
