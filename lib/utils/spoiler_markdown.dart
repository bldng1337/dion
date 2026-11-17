import 'package:markdown/markdown.dart' as md;

const spoilerTag = 'spoiler';

class SpoilerSyntax extends md.InlineSyntax {
  SpoilerSyntax() : super(r'\|\|([^\n]+?)\|\|', startCharacter: 0x7C);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text(spoilerTag, match[1]!));
    return true;
  }
}
