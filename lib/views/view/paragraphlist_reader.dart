import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SimpleParagraphlistReader extends StatelessWidget {
  final SourcePath source;
  DataSource_Paragraphlist get sourcedata =>
      source.source.sourcedata as DataSource_Paragraphlist;
  const SimpleParagraphlistReader({super.key, required this.source});

  @override
  Widget build(BuildContext context) {
    final paragraphs = sourcedata.paragraphs;
    return NavScaff(
      title: Text(source.name),
      child: ListView.builder(
        itemBuilder: (context, index) {
          if (index == paragraphs.length) {
            if (source.episode.hasnext) {
              return DionTextbutton(
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
          ).paddingOnly(
            bottom: 1,
          );
        },
        itemCount: paragraphs.length + 1,
      ),
    );
  }
}
