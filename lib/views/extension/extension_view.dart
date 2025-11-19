import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/badge.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/foldabletext.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/dion_runtime.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

class ExtensionView extends StatefulWidget {
  const ExtensionView({super.key});

  @override
  _ExtensionViewState createState() => _ExtensionViewState();
}

class _ExtensionViewState extends State<ExtensionView> {
  Extension? extension;
  Object? error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final ext = locate<SourceExtension>().getExtension(
        GoRouterState.of(context).pathParameters['id']!,
      );
      setState(() {
        extension = ext;
      });
    } catch (e) {
      error = e;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return NavScaff(
        title: Text('Error Loading ${extension?.name ?? ''}'),
        child: Center(child: ErrorDisplay(e: error)),
      );
    }
    if (extension == null) {
      return const NavScaff(
        title: Text('Loading ...'),
        child: Center(child: DionProgressBar()),
      );
    }
    return NavScaff(
      child: Column(
        children: [
          Row(
            children: [
              DionImage(
                imageUrl: extension!.data.icon,
                width: 100,
                height: 100,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(extension!.name, style: context.titleLarge),
                      DionBadge(
                        child: Text(
                          extension!.data.version ?? '',
                          style: context.bodyMedium,
                        ),
                      ).paddingAll(5),
                    ],
                  ),
                  if (extension!.data.author.isNotEmpty)
                    Text(
                      'by ${extension!.data.author}',
                      style: context.bodyMedium,
                    ),
                ],
              ).paddingAll(10),
            ],
          ).paddingAll(30),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (extension!.data.desc != null &&
                      extension!.data.desc!.isNotEmpty) ...[
                    Foldabletext(
                      extension!.data.desc ?? '',
                      style: context.bodyMedium,
                    ),
                    const Divider(),
                  ],
                  for (final e in extension!.settings[SettingKind.extension_]!)
                    DionRuntimeSettingView(setting: e),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
