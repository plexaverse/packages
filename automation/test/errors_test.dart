import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_automation/in_app_automation.dart';

void main() {
  group('AutomationException hierarchy', () {
    test('every typed error is an AutomationException and an Exception', () {
      final errors = <AutomationException>[
        const ElementNotFoundException('a'),
        const AutomationTimeoutException('b'),
        const NotVisibleException('c'),
        const NotActionableException('d'),
        const AmbiguousMatchException('e'),
        const AutomationAssertionException('f'),
      ];
      for (final e in errors) {
        expect(e, isA<AutomationException>());
        expect(e, isA<Exception>());
      }
    });

    test('toString includes the runtime type and message', () {
      expect(
        const ElementNotFoundException('nope').toString(),
        'ElementNotFoundException: nope',
      );
    });

    test('message is preserved', () {
      expect(const NotVisibleException('hidden').message, 'hidden');
    });

    test('subtypes are distinguishable when caught', () {
      Object? caught;
      try {
        throw const AmbiguousMatchException('two matches');
      } on ElementNotFoundException {
        caught = 'wrong';
      } on AmbiguousMatchException catch (e) {
        caught = e;
      }
      expect(caught, isA<AmbiguousMatchException>());
    });
  });
}
