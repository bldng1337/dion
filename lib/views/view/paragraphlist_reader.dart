import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/appsettings.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:text_scroll/text_scroll.dart';

final psettings = settings.readerSettings.paragraphreader;

class SimpleParagraphlistReader extends StatelessWidget {
  final SourcePath source;
  DataSource_Paragraphlist get sourcedata =>
      source.source.sourcedata as DataSource_Paragraphlist;
  const SimpleParagraphlistReader({super.key, required this.source});

  Widget wrapScreen(BuildContext context, Widget child) {
    return ListenableBuilder(
      listenable: psettings.text.selectable,
      builder: (context, child) {
        if (psettings.text.selectable.value) {
          return SelectionArea(child: child!);
        }
        return child!;
      },
      child: ListenableBuilder(
        listenable: Listenable.merge(
          [
            psettings.text.linewidth,
            psettings.text.adaptivewidth,
          ],
        ),
        builder: (context, child) {
          if (psettings.text.adaptivewidth.value &&
              context.width < context.height) {
            return child!;
          }
          final width =
              context.width * (1 - (psettings.text.linewidth.value / 100));
          final padding = width / 2;
          return child!.paddingOnly(
            left: padding,
            right: padding,
          );
        },
        child: child,
      ),
    );
  }

  Widget makeParagraph(BuildContext context, String text) {
    return ListenableBuilder(
      listenable: psettings.text.paragraphspacing,
      builder: (context, child) =>
          child!.paddingOnly(bottom: psettings.text.paragraphspacing.value*2),
      child: ListenableBuilder(
        listenable: Listenable.merge([
          psettings.text.linespacing,
          psettings.text.size,
          psettings.text.weight,
        ]),
        builder: (context, child) => Text(
          text,
          style: context.bodyLarge?.copyWith(
            height: psettings.text.linespacing.value,
            fontSize: psettings.text.size.value.toDouble(),
            fontWeight: FontWeight.lerp(
              FontWeight.w100,
              FontWeight.w900,
              psettings.text.weight.value,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paragraphs = sourcedata.paragraphs;
    return NavScaff(
      title: TextScroll(source.name),
      actions: [
        DionIconbutton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings/paragraphreader')),
      ],
      child: wrapScreen(
        context,
        ListView.builder(
          itemBuilder: (context, index) {
            if (index == 0) {
              return ListenableBuilder(
                listenable: psettings.title,
                builder: (context, child) => psettings.title.value
                    ? Text(source.name, style: context.titleLarge)
                    : nil,
              );
            }
            if (index-1 == paragraphs.length) {
              if (source.episode.hasnext) {
                return DionTextbutton(
                  child: const Text('Next'),
                  onPressed: () => GoRouter.of(context)
                      .pushReplacement('/view', extra: [source.episode.next]),
                );
              }
              return nil;
            }
            return makeParagraph(context, paragraphs[index - 1]);
          },
          itemCount: paragraphs.length + 2,
        ),
      ),
    );
  }
}
