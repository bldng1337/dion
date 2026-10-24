import 'package:markdown/markdown.dart' as md;

const wikiLinkScheme = 'dion-wiki';

class WikiLinkSyntax extends md.InlineSyntax {
  WikiLinkSyntax()
    : super(r'\[\[((?:[^\[\]\n]|\[[^\]\n]*\])*?)(?:\|([^\[\]\n]+?))?\]\]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final target = match[1]!.trim();
    final alias = match[2]?.trim();
    final anchor = md.Element.text(
      'a',
      alias == null || alias.isEmpty ? target : alias,
    );
    anchor.attributes['href'] = '$wikiLinkScheme:${encodeWikiTarget(target)}';
    parser.addNode(anchor);
    return true;
  }
}

String encodeWikiTarget(String target) => Uri.encodeComponent(target);

String? decodeWikiTarget(String? href) {
  if (href == null) return null;
  const prefix = '$wikiLinkScheme:';
  if (!href.startsWith(prefix)) return null;
  return Uri.decodeComponent(href.substring(prefix.length));
}

({String? entryTitle, String? chapter})? parseWikiTarget(String target) {
  final trimmed = target.trim();
  if (trimmed.isEmpty) return null;
  final hash = trimmed.indexOf('#');
  if (hash < 0) return (entryTitle: trimmed, chapter: null);
  final title = hash == 0 ? '' : trimmed.substring(0, hash).trim();
  final chapter = trimmed.substring(hash + 1).trim();
  if (title.isEmpty && chapter.isEmpty) return null;
  return (
    entryTitle: title.isEmpty ? null : title,
    chapter: chapter.isEmpty ? null : chapter,
  );
}
