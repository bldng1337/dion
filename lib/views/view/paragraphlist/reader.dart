import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/views/view/paragraphlist/infinite_reader.dart';
import 'package:dionysos/views/view/paragraphlist/simple_reader.dart';
import 'package:dionysos/views/view/wrapper.dart';
import 'package:flutter/cupertino.dart';
import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'dart:math';
import 'package:dionysos/widgets/selection.dart';
import 'package:dionysos/service/source_extension.dart';

import 'package:dionysos/widgets/errordisplay.dart';
import 'package:flutter/material.dart';

final psettings = settings.readerSettings.paragraphreader;

class ParagraphListReader extends StatelessWidget {
  final SourceSupplier supplier;

  const ParagraphListReader({super.key, required this.supplier});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: psettings.mode,
      builder: (context, child) => switch (psettings.mode.value) {
        ReaderMode.paginated => SourceWrapper(
          builder: (context, source) =>
              SimpleParagraphlistReader(source: source, supplier: supplier),
          source: supplier,
        ),
        ReaderMode.infinite => InfiniteParagraphListReader(supplier: supplier),
      },
    );
  }
}

class ReaderWrapScreen extends StatelessWidget {
  final Widget child;
  const ReaderWrapScreen(this.child, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        psettings.text.linewidth,
        psettings.text.adaptivewidth,
        psettings.text.selectable,
      ]),
      builder: (context, child) {
        if (psettings.text.adaptivewidth.value &&
            context.width < context.height) {
          if (psettings.text.selectable.value) {
            return Selection(child: child!);
          }
          return child!;
        }
        final width =
            context.width * (1 - (psettings.text.linewidth.value / 100));
        final padding = width / 2;
        if (psettings.text.selectable.value) {
          return Selection(
            child: child!,
          ).paddingOnly(left: padding, right: padding);
        }
        return child!.paddingOnly(left: padding, right: padding);
      },
      child: child,
    );
  }
}

class ReaderRenderParagraph extends StatelessWidget {
  final Paragraph text;
  const ReaderRenderParagraph(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: psettings.text.paragraphspacing,
      builder: (context, child) =>
          child!.paddingOnly(bottom: psettings.text.paragraphspacing.value * 5),
      child: ListenableBuilder(
        listenable: Listenable.merge([
          psettings.text.linespacing,
          psettings.text.size,
          psettings.text.weight,
          psettings.text.bionic,
        ]),
        builder: (context, child) => makeParagraph(context, text),
      ),
    );
  }

  Widget makeParagraph(BuildContext context, Paragraph text) {
    switch (text) {
      case final Paragraph_Text text:
        if (psettings.text.bionic.value) {
          return ListenableBuilder(
            listenable: Listenable.merge([
              psettings.text.bionicSettings.bionicWheight,
              psettings.text.bionicSettings.bionicSize,
              psettings.text.bionicSettings.letters,
            ]),
            builder: (context, child) => BionicText(
              content: text.content,
              basicStyle: context.bodyLarge?.copyWith(
                height: psettings.text.linespacing.value,
                fontSize: psettings.text.size.value.toDouble(),
                fontWeight: FontWeight.lerp(
                  FontWeight.w100,
                  FontWeight.w900,
                  psettings.text.weight.value,
                ),
              ),
              letters: psettings.text.bionicSettings.letters.value,
              markStyle: context.bodyLarge?.copyWith(
                height: psettings.text.linespacing.value,
                fontSize: psettings.text.bionicSettings.bionicSize.value
                    .toDouble(),
                fontWeight: FontWeight.lerp(
                  FontWeight.w100,
                  FontWeight.w900,
                  psettings.text.bionicSettings.bionicWheight.value,
                ),
              ),
            ),
          );
        }
        return Text(
          text.content,
          style: context.bodyLarge?.copyWith(
            height: psettings.text.linespacing.value,
            fontSize: psettings.text.size.value.toDouble(),
            fontWeight: FontWeight.lerp(
              FontWeight.w100,
              FontWeight.w900,
              psettings.text.weight.value,
            ),
          ),
        );
      case Paragraph_CustomUI():
        return ErrorDisplay(
          e: Exception('CustomUI not implemented'),
          message: 'CustomUI not yet implemented',
        ); //TODO: Implement CustomUI
    }
  }
}

class BionicText extends StatelessWidget {
  final String content;
  final int letters;
  final TextStyle? markStyle;
  final TextStyle? basicStyle;

  const BionicText({
    super.key,
    required this.content,
    this.letters = 1,
    this.markStyle = const TextStyle(fontWeight: FontWeight.bold),
    this.basicStyle = const TextStyle(),
  });

  @override
  Widget build(BuildContext context) {
    final display = content.split(' ').map(renderSpan).toList(growable: false);
    return RichText(text: TextSpan(children: display));
  }

  InlineSpan renderSpan(String content) {
    if (!content.startsWith(RegExp('[A-Za-z0-9]'))) {
      return TextSpan(text: '$content ', style: basicStyle);
    }
    if (content.length == 1) TextSpan(text: '$content ', style: markStyle);

    final sub = min(letters, content.length);

    return TextSpan(
      children: [
        TextSpan(text: content.substring(0, sub), style: markStyle),
        TextSpan(
          text: '${content.substring(sub, content.length)} ',
          style: basicStyle,
        ),
      ],
    );
  }
}
