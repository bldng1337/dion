class TextReplacement {
  final String find;
  final String replaceWith;

  const TextReplacement({required this.find, this.replaceWith = ''});

  bool get isStripping => replaceWith.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is TextReplacement &&
      find == other.find &&
      replaceWith == other.replaceWith;

  @override
  int get hashCode => Object.hash(find, replaceWith);

  @override
  String toString() =>
      'TextReplacement{find: $find, replaceWith: $replaceWith}';

  Map<String, dynamic> toJson() => {'find': find, 'replaceWith': replaceWith};

  factory TextReplacement.fromJson(Map<String, dynamic> json) {
    return TextReplacement(
      find: json['find'] as String,
      replaceWith: json['replaceWith'] as String? ?? '',
    );
  }
}

String applyTextReplacements(String input, Iterable<TextReplacement> rules) {
  var result = input;
  for (final rule in rules) {
    if (rule.find.isEmpty) continue;
    result = result.replaceAll(rule.find, rule.replaceWith);
  }
  return result;
}
