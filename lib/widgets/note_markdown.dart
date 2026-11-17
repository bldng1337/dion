import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/spoiler_markdown.dart';
import 'package:dionysos/utils/wiki_markdown.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

class NoteMarkdown extends StatefulWidget {
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
  State<NoteMarkdown> createState() => _NoteMarkdownState();
}

class _NoteMarkdownState extends State<NoteMarkdown>
    with StateDisposeScopeMixin {
  final Set<String> _revealed = {};
  final Map<String, TapGestureRecognizer> _recognizers = {};

  int _revealVersion = 0;

  TapGestureRecognizer _recognizerFor(String spoiler) =>
      _recognizers.putIfAbsent(spoiler, () {
        final recognizer = TapGestureRecognizer()..disposedBy(scope);
        recognizer.onTap = () => setState(() {
          if (!_revealed.remove(spoiler)) _revealed.add(spoiler);
          _revealVersion++;
        });
        return recognizer;
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cover = theme.colorScheme.onSurface.withValues(alpha: 0.85);
    return Markdown(
      key: ValueKey(_revealVersion),
      data: widget.data,
      noScroll: true,
      padding: widget.padding,
      inlineSyntaxes: [WikiLinkSyntax(), SpoilerSyntax()],
      builders: {
        spoilerTag: _SpoilerBuilder(
          recognizerFor: _recognizerFor,
          isRevealed: _revealed.contains,
          hiddenStyle: TextStyle(
            color: Colors.transparent,
            backgroundColor: cover,
          ),
          revealedStyle: TextStyle(backgroundColor: context.surfaceMuted),
        ),
      },
      styleSheet: MarkdownStyleSheet.fromTheme(theme)
          .copyWith(a: TextStyle(color: theme.colorScheme.primary)),
      onTapLink: (text, href, title) {
        final target = decodeWikiTarget(href);
        if (target != null) {
          widget.onWikiLink?.call(target);
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

class _SpoilerBuilder extends MarkdownElementBuilder {
  final TapGestureRecognizer Function(String spoiler) recognizerFor;
  final bool Function(String spoiler) isRevealed;
  final TextStyle hiddenStyle;
  final TextStyle revealedStyle;

  _SpoilerBuilder({
    required this.recognizerFor,
    required this.isRevealed,
    required this.hiddenStyle,
    required this.revealedStyle,
  });

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final text = element.textContent;
    final style = isRevealed(text) ? revealedStyle : hiddenStyle;
    return Text.rich(
      TextSpan(
        text: text,
        recognizer: recognizerFor(text),
        mouseCursor: SystemMouseCursors.click,
        style: parentStyle?.merge(style) ?? style,
      ),
    );
  }
}
