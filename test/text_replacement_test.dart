import 'package:dionysos/data/text_replacement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('applyTextReplacements', () {
    test('strips every occurrence when the replacement is empty', () {
      const rules = [TextReplacement(find: '[Illustration]')];
      expect(
        applyTextReplacements(
          'He stood up.[Illustration] Then he left.[Illustration]',
          rules,
        ),
        'He stood up. Then he left.',
      );
    });

    test('replaces with the configured text', () {
      const rules = [TextReplacement(find: 'MC', replaceWith: 'protagonist')];
      expect(
        applyTextReplacements('The MC smiled.', rules),
        'The protagonist smiled.',
      );
    });

    test('applies rules in order', () {
      const rules = [
        TextReplacement(find: 'ab', replaceWith: 'x'),
        TextReplacement(find: 'x', replaceWith: 'y'),
      ];
      expect(applyTextReplacements('ab x', rules), 'y y');
    });

    test('skips rules with an empty find pattern', () {
      const rules = [
        TextReplacement(find: '', replaceWith: 'boom'),
        TextReplacement(find: 'a', replaceWith: 'b'),
      ];
      expect(applyTextReplacements('aa', rules), 'bb');
    });

    test('matching is case sensitive', () {
      const rules = [TextReplacement(find: 'Foo')];
      expect(applyTextReplacements('foo Foo FOO', rules), 'foo  FOO');
    });
  });

  group('TextReplacement json', () {
    test('round trips', () {
      const rule = TextReplacement(find: 'old', replaceWith: 'new');
      expect(TextReplacement.fromJson(rule.toJson()), rule);
    });

    test('defaults a missing replacement to stripping', () {
      expect(TextReplacement.fromJson({'find': 'x'}).replaceWith, '');
    });
  });
}
