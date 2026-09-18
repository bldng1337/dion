import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/views/view/chapters/chapter_controller.dart';
import 'package:dionysos/widgets/dialog.dart';
import 'package:flutter/material.dart';

String _formatDuration(Duration duration) {
  final h = duration.inHours;
  final m = duration.inMinutes.remainder(60);
  final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

Future<void> showChapterSheet(
  BuildContext context,
  ChapterController controller,
) {
  return showDialog(
    context: context,
    builder: (context) {
      return DionDialog(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final chapters = controller.chapters;
            return ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 400,
                maxHeight: 500,
                minWidth: 280,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      left: DionSpacing.lg,
                      top: DionSpacing.lg,
                    ),
                    child: Text(
                      'Chapters',
                      style: context.theme.textTheme.titleMedium,
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(DionSpacing.sm),
                      itemCount: chapters.length,
                      itemBuilder: (context, index) {
                        final chapter = chapters[index];
                        final current = index == controller.currentIndex;
                        final end = controller.endOf(chapter);
                        return ListTile(
                          selected: current,
                          dense: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(DionRadius.md),
                            ),
                          ),
                          leading: current
                              ? const Icon(Icons.play_arrow)
                              : Text('${index + 1}'),
                          title: Text(
                            chapter.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${_formatDuration(chapter.start)} - ${_formatDuration(end)}',
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            controller.goToChapter(index);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}
