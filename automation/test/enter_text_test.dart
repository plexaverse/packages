import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:automation/automation.dart';

void main() {
  testWidgets('enterText updates the controller and fires onChanged', (tester) async {
    final controller = TextEditingController();
    String? changed;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TextField(
          key: const Key('f'),
          controller: controller,
          onChanged: (v) => changed = v,
        ),
      ),
    ));

    await tester.runAsync(() async {
      await AutomationEngine.instance.enterText(const Key('f'), 'hello', timeout: const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();

    expect(controller.text, 'hello');
    expect(changed, 'hello');
    // Caret is placed at the end of the inserted text.
    expect(controller.selection.baseOffset, 'hello'.length);
  });

  testWidgets('enterText honours inputFormatters', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TextField(
          key: const Key('f'),
          controller: controller,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
      ),
    ));

    await tester.runAsync(() async {
      await AutomationEngine.instance.enterText(const Key('f'), 'a1b2c3', timeout: const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();

    expect(controller.text, '123');
  });

  testWidgets('enterText with submit:true fires onSubmitted', (tester) async {
    String? submitted;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TextField(
          key: const Key('f'),
          onSubmitted: (v) => submitted = v,
        ),
      ),
    ));

    await tester.runAsync(() async {
      await AutomationEngine.instance
          .enterText(const Key('f'), 'done', submit: true, timeout: const Duration(seconds: 2));
    });
    await tester.pumpAndSettle();

    expect(submitted, 'done');
  });
}
