import 'dart:convert';

/// A line consisting of 3+ of the same separator punctuation character.
final RegExp _separatorLineRegExp = RegExp(r'^[\s]*([-=*_~/#|.,])\1{2,}[\s]*$');

/// Three or more consecutive newlines (with optional whitespace between them).
final RegExp _blankRunRegExp = RegExp(r'\n[ \t]*\n([ \t]*\n){1,}');

/// Regularise [input] text for spoken output.
String regulariseText(
  String input, {
  required bool stripSeparators,
  required bool collapseBlankLines,
}) {
  var result = input;

  if (stripSeparators) {
    final lines = const LineSplitter().convert(result);
    final kept = <String>[];
    for (final line in lines) {
      if (_separatorLineRegExp.hasMatch(line)) continue;
      kept.add(line);
    }
    result = kept.join('\n');
  }

  if (collapseBlankLines) {
    result = result.replaceAll(_blankRunRegExp, '\n\n');
  }

  return result.trim();
}
