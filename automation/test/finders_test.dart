import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:automation/automation.dart' as auto;

void main() {
  Element root() => WidgetsBinding.instance.rootElement!;

  testWidgets('byText matches a Text exactly once (no RichText double-match)', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Hello'))));
    expect(auto.find.byText('Hello').findAll(root()).length, 1);
  });

  testWidgets('byText is exact; textContaining does substring and regex', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Item 42'))));

    expect(auto.find.byText('Item').findAll(root()), isEmpty);
    expect(auto.find.textContaining('Item').findAll(root()).length, 1);
    expect(auto.find.textContaining(RegExp(r'\d+')).findAll(root()).length, 1);
  });

  testWidgets('first / at / last select among multiple matches', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(children: [Text('Row'), Text('Row'), Text('Row')]),
      ),
    ));

    final rows = auto.find.byText('Row');
    expect(rows.findAll(root()).length, 3);
    expect(rows.first.findAll(root()).length, 1);
    expect(rows.at(1).findAll(root()).length, 1);
    expect(rows.last.findAll(root()).length, 1);
    expect(rows.at(9).findAll(root()), isEmpty);

    // first, at(0), and the raw first element are the same element.
    expect(rows.first.findFirst(root()), same(rows.findAll(root()).first));
    expect(rows.last.findFirst(root()), same(rows.findAll(root()).last));
  });

  testWidgets('byWidget matches subtypes; byType matches exact runtime type only', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ElevatedButton(onPressed: () {}, child: const Text('Go'))),
    ));

    // ElevatedButton is a ButtonStyleButton subtype.
    expect(auto.find.byWidget<ButtonStyleButton>().findAll(root()).length, 1);
    // Exact-type match against the abstract base finds nothing.
    expect(auto.find.byType(ButtonStyleButton).findAll(root()), isEmpty);
    // Exact-type match against the concrete type works.
    expect(auto.find.byType(ElevatedButton).findAll(root()).length, 1);
  });

  testWidgets('byTooltip matches a Tooltip by message', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Tooltip(message: 'Delete', child: Icon(Icons.delete))),
    ));
    expect(auto.find.byTooltip('Delete').findAll(root()).length, 1);
    expect(auto.find.byTooltip('Nope').findAll(root()), isEmpty);
  });
}
