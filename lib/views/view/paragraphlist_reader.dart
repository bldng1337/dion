import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:go_router/go_router.dart';

class SimpleParagraphlistReader extends StatelessWidget {
  final SourcePath source;
  DataSource_Paragraphlist get sourcedata =>
      source.source.sourcedata as DataSource_Paragraphlist;
  const SimpleParagraphlistReader({super.key, required this.source});

  @override
  Widget build(BuildContext context) {
    final paragraphs = sourcedata.paragraphs;
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(source.name),
      ),
      body: ListView.builder(
        itemBuilder: (context, index) {
          if (index == paragraphs.length) {
            if (source.episode.hasnext) {
              return PlatformTextButton(
                child: const Text('Next'),
                onPressed: () => GoRouter.of(context)
                    .pushReplacement('/view', extra: source.episode.next),
              );
            }
            return nil;
          }
          return Text(
            paragraphs[index],
            style: context.bodyLarge,
          ).paddingOnly(bottom: 0);
        },
        itemCount: paragraphs.length + 1,
      ),
    );
  }
}
