import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_automation/in_app_automation.dart';

void main() {
  testWidgets('captureScreenshot returns PNG bytes of the app content', (tester) async {
    await tester.pumpWidget(
      const AutomationInspectorWrapper(
        child: MaterialApp(home: Scaffold(body: ColoredBox(color: Colors.red))),
      ),
    );
    await tester.pump();

    Uint8List? bytes;
    await tester.runAsync(() async {
      bytes = await AutomationScreenshot.capture(pixelRatio: 1.0);
    });

    expect(bytes, isNotNull);
    expect(bytes!.length, greaterThan(8));
    // PNG magic number: 0x89 'P' 'N' 'G'.
    expect(bytes!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  testWidgets('capture returns null when no boundary is mounted', (tester) async {
    // A bare app without the wrapper -> no screenshot boundary registered.
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('no wrapper'))));

    Uint8List? bytes;
    await tester.runAsync(() async {
      bytes = await AutomationScreenshot.capture();
    });

    expect(bytes, isNull);
  });
}
