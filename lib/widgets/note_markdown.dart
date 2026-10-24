import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/wiki_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class NoteMarkdown extends StatelessWidget {
  final String data;
  final void Function(String target)? onWikiLink;
  final EdgeInsets padding;

  const NoteMarkdown({
    super.key,
    required this.data,
    this.onWikiLink,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Markdown(
      data: data,
      noScroll: true,
      padding: padding,
      inlineSyntaxes: [WikiLinkSyntax()],
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
          .copyWith(a: TextStyle(color: Theme.of(context).colorScheme.primary)),
      onTapLink: (text, href, title) {
        final target = decodeWikiTarget(href);
        if (target != null) {
          onWikiLink?.call(target);
          return;
        }
        if (href != null) {
          try {
            launchUrl(Uri.parse(href));
          } catch (e) {
            logger.w('Failed to open note link $href', error: e);
          }
        }
      },
    );
  }
}
