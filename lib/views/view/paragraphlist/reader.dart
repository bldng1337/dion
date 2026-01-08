import 'package:dionysos/data/font.dart';
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/utils/async.dart';
import 'package:dionysos/views/customui.dart';
import 'package:dionysos/views/view/paragraphlist/infinite_reader.dart';
import 'package:dionysos/views/view/paragraphlist/simple_reader.dart';
import 'package:dionysos/views/view/wrapper.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/cupertino.dart';
import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'dart:math';
import 'package:dionysos/widgets/selection.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/views/view/view.dart';
import 'package:dionysos/views/view/session.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:flutter/material.dart';

final psettings = settings.readerSettings.paragraphreader;

class ParagraphListReader extends StatelessWidget {
  const ParagraphListReader({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: psettings.font,
      builder: (context, child) => LoadingBuilder(
        future: psettings.font.value.toTextStyle(),
        loading: (context) =>
            const NavScaff(child: Center(child: DionProgressBar())),
        builder: (context, value) => ListenableBuilder(
          listenable: psettings.mode,
          builder: (context, child) => switch (psettings.mode.value) {
            ReaderMode.paginated => SourceWrapper(
              builder: (context, source) => SimpleParagraphlistReader(
                key: ValueKey(source.episode),
                source: source,
                supplier: SourceSuplierData.of(context)!.supplier,
              ),
              source: SourceSuplierData.of(context)!.supplier,
            ),
            ReaderMode.infinite => InfiniteParagraphListReader(
              supplier: SourceSuplierData.of(context)!.supplier,
            ),
          },
        ),
      ),
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
  final Extension extension;
  const ReaderRenderParagraph(this.text, this.extension, {super.key});

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
              psettings.font,
            ]),
            builder: (context, child) {
              return LoadingBuilder(
                future: psettings.font.value.toTextStyle(),
                builder: (context, style) => BionicText(
                  content: text.content,
                  basicStyle: (context.bodyLarge ?? style)
                      .merge(style)
                      .copyWith(
                        height: psettings.text.linespacing.value,
                        fontSize: psettings.text.size.value.toDouble(),
                        fontWeight: FontWeight.lerp(
                          FontWeight.w100,
                          FontWeight.w900,
                          psettings.text.weight.value,
                        ),
                      ),
                  letters: psettings.text.bionicSettings.letters.value,
                  markStyle: (context.bodyLarge ?? style)
                      .merge(style)
                      .copyWith(
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
                error: (context, _, _) => BionicText(
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
                loading: (context) => BionicText(
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
            },
          );
        }
        return ListenableBuilder(
          listenable: psettings.font,
          builder: (context, child) {
            return Text(
              text.content,
              style: (context.bodyLarge ?? const TextStyle())
                  .copyWith(
                    height: psettings.text.linespacing.value,
                    fontSize: psettings.text.size.value.toDouble(),
                    fontWeight: FontWeight.lerp(
                      FontWeight.w100,
                      FontWeight.w900,
                      psettings.text.weight.value,
                    ),
                  )
                  .merge(psettings.font.value.syncTextStyle),
            );
            // return LoadingBuilder(
            //   future: psettings.font.value.toTextStyle(),
            //   builder: (context, style) => Text(
            //     text.content,
            //     style: (context.bodyLarge ?? style)
            //         .merge(style)
            //         .copyWith(
            //           height: psettings.text.linespacing.value,
            //           fontSize: psettings.text.size.value.toDouble(),
            //           fontWeight: FontWeight.lerp(
            //             FontWeight.w100,
            //             FontWeight.w900,
            //             psettings.text.weight.value,
            //           ),
            //         ),
            //   ),
            //   loading: (context) => Text(
            //     text.content,
            //     style: context.bodyLarge?.copyWith(
            //       height: psettings.text.linespacing.value,
            //       fontSize: psettings.text.size.value.toDouble(),
            //       fontWeight: FontWeight.lerp(
            //         FontWeight.w100,
            //         FontWeight.w900,
            //         psettings.text.weight.value,
            //       ),
            //     ),
            //   ),
            //   error: (context, _, _) => Text(
            //     text.content,
            //     style: context.bodyLarge?.copyWith(
            //       height: psettings.text.linespacing.value,
            //       fontSize: psettings.text.size.value.toDouble(),
            //       fontWeight: FontWeight.lerp(
            //         FontWeight.w100,
            //         FontWeight.w900,
            //         psettings.text.weight.value,
            //       ),
            //     ),
            //   ),
            // );
          },
        );
      case final Paragraph_CustomUI customUi:
        return CustomUIWidget.fromUI(ui: customUi.ui, extension: extension);
      case final Paragraph_Table table:
        return Table(
          border: TableBorder.all(color: Colors.grey.shade300),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            for (final row in table.columns)
              TableRow(
                children: [
                  for (final cell in row.cells)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ReaderRenderParagraph(cell, extension),
                    ),
                ],
              ),
          ],
        );
    }
  }
}

class EpisodeTitle extends StatelessWidget {
  final EpisodePath episode;
  const EpisodeTitle({super.key, required this.episode});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        psettings.title,
        psettings.titleSettings.size,
        psettings.titleSettings.thumbBanner,
      ]),
      builder: (context, child) {
        if (!psettings.title.value) {
          return const SizedBox.shrink();
        }
        final cover = episode.cover ?? episode.entry.cover;
        final baseStyle = context.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: psettings.titleSettings.size.value.toDouble(),
          letterSpacing: 0.2,
          height: 1.1,
        );
        final title = Container(
          padding: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
          alignment: Alignment.center,
          child: Text(
            episode.name,
            style: baseStyle,
            textAlign: TextAlign.center,
            softWrap: true,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        );

        if (cover != null && psettings.titleSettings.thumbBanner.value) {
          final titleOnImageStyle =
              baseStyle?.copyWith(
                color: Colors.white,
                shadows: [
                  const Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 4,
                    color: Colors.black54,
                  ),
                ],
              ) ??
              const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 4,
                    color: Colors.black54,
                  ),
                ],
              );

          final titleOnImage = Container(
            padding: const EdgeInsets.only(
              bottom: 60,
              left: 16,
              right: 16,
              top: 30,
            ),
            alignment: Alignment.center,
            child: Text(
              episode.name,
              style: titleOnImageStyle,
              textAlign: TextAlign.center,
              softWrap: true,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          );
          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: DionImage(
                  imageUrl: cover.url,
                  httpHeaders: cover.header,
                  boxFit: BoxFit.cover,
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color.fromRGBO(0, 0, 0, 0.45),
                      ],
                    ),
                  ),
                ),
              ),
              titleOnImage,
              (psettings.titleSettings.size.value.toDouble() * 5).heightBox,
              ListenableBuilder(
                listenable: psettings.titleSettings.progressBar,
                builder: (context, child) {
                  final session= SessionData.of(context)!.session;
                  final totalEpisodes = episode.entry.episodes.length;
                  final fromFraction = session.fromepisode / totalEpisodes;
                  final toFraction = session.toepisode / totalEpisodes;
                  const barHeight = 6.0;
                  return Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Stack(
                      children: [
                        Container(
                          height: barHeight,
                          color: Colors.black.withValues(alpha: 0.15),
                        ),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: toFraction.clamp(0.0, 1.0),
                          child: Container(
                            height: barHeight,
                            color: context.theme.colorScheme.primary.lighten(25),
                          ),
                        ),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: fromFraction.clamp(0.0, 1.0),
                          child: Container(
                            height: barHeight,
                            color: context.theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ).paddingOnly(bottom: 20);
        }
        return title;
      },
    );
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
