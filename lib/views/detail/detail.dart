import 'dart:async';
import 'dart:math';

import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/entry/entry_detailed.dart';
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/source_extension.dart';
import 'package:dionysos/utils/cancel_token.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/views/detail/entryinfo.dart';
import 'package:dionysos/views/detail/episodelist.dart';
import 'package:dionysos/views/detail/settings.dart';
import 'package:dionysos/widgets/bounds.dart';
import 'package:dionysos/widgets/buttons/actionbutton.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/tabbar.dart';
import 'package:dionysos/widgets/text_scroll.dart';
import 'package:flutter/material.dart' show Colors, Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class Detail extends StatefulWidget {
  const Detail({super.key});

  @override
  _DetailState createState() => _DetailState();
}

class _DetailState extends State<Detail> with StateDisposeScopeMixin {
  Entry? entry;
  late CancelToken tok;
  Object? error;
  StackTrace? errstack;

  Future<void> loadEntry() async {
    try {
      final saved = await locate<Database>().isSaved(entry!);
      if (saved != null) {
        entry = saved;
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e, stack) {
      logger.e('Error checking if entry is saved', error: e, stackTrace: stack);
      error = e;
      if (mounted) {
        setState(() {});
      }
    }
    try {
      entry = await entry!.toDetailed(token: tok);
      if (mounted) {
        setState(() {});
      }
    } catch (e, stack) {
      logger.e('Error loading entry', error: e, stackTrace: stack);
      error = e;
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newentry =
        (GoRouterState.of(context).extra! as List<Object?>)[0]! as Entry;
    setState(() {});
    if (newentry is EntryDetailed || newentry is EntrySaved) {
      entry = newentry;
      return;
    }
    if (entry is EntryDetailed && newentry.id == entry?.id) return;
    if (entry is EntrySaved && newentry.id == entry?.id) return;
    if (!mounted) return;
    entry = newentry;
    if (tok.isDisposed) {
      tok = CancelToken()..disposedBy(scope);
    }
    loadEntry();
  }

  @override
  void initState() {
    super.initState();
    tok = CancelToken()..disposedBy(scope);
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return NavScaff(
        child: ErrorDisplay(e: error, s: errstack),
      );
    }
    if (entry == null) {
      return const NavScaff(child: Center(child: DionProgressBar()));
    }
    final ext = entry!.extension;
    if (entry is EntryDetailed && ext != null) {
      return ListenableBuilder(
        listenable: ext,
        builder: (context, child) => buildDetailScreen(context),
      );
    }
    return buildDetailScreen(context);
  }

  Widget buildDetailScreen(BuildContext context) {
    final actions = [
      if (entry is EntrySaved && (entry!.extension?.isenabled ?? false))
        DionIconbutton(
          onPressed: () {
            showSettingPopup(context, entry! as EntrySaved);
          },
          icon: const Icon(Icons.settings),
        ),
      if (entry is EntrySaved && (entry!.extension?.isenabled ?? false))
        DionIconbutton(
          onPressed: () async {
            try {
              if (tok.isDisposed) {
                tok = CancelToken()..disposedBy(scope);
              }
              final e = await (entry! as EntrySaved).refresh(token: tok);
              entry = e;
              if (mounted) {
                setState(() {});
              }
            } catch (e, stack) {
              error = e;
              errstack = stack;
              if (mounted) {
                setState(() {});
              }
            }
          },
          icon: const Icon(Icons.refresh),
        ),
      if (entry is EntryDetailed)
        DionIconbutton(
          onPressed: () {
            try {
              launchUrl(Uri.parse(entry!.url));
            } catch (e) {
              error = e;
              if (mounted) {
                setState(() {});
              }
            }
          },
          icon: const Icon(Icons.open_in_browser),
        ),
    ];
    if (context.width < 950) {
      return NavScaff(
        actions: actions,
        floatingActionButton:
            (entry is EntrySaved && (entry!.extension?.isenabled ?? false))
            ? ActionButton(
                onPressed: () {
                  EpisodePath(
                    entry! as EntryDetailed,
                    min(
                      (entry! as EntrySaved).latestEpisode,
                      (entry! as EntrySaved).episodes.length - 1,
                    ),
                  ).go(context);
                },
                child: const Icon(Icons.play_arrow),
              )
            : null,
        title: DionTextScroll(entry?.title ?? ''),
        child: DionTabBar(
          tabs: [
            DionTab(
              tab: const DionTextScroll('Info').paddingAll(5),
              child: EntryInfo(entry: entry!),
            ),
            if (entry is EntryDetailed)
              DionTab(
                tab: const DionTextScroll('Episodes').paddingAll(5),
                child: EpisodeListUI(entry: entry! as EntryDetailed),
              ),
          ],
        ),
      );
    }
    return NavScaff(
      actions: actions,
      floatingActionButton:
          (entry is EntrySaved && (entry!.extension?.isenabled ?? false))
          ? ActionButton(
              onPressed: () {
                EpisodePath(
                  entry! as EntryDetailed,
                  min(
                    (entry! as EntrySaved).latestEpisode,
                    (entry! as EntrySaved).episodes.length - 1,
                  ),
                ).go(context);
              },
              child: const Icon(Icons.play_arrow),
            )
          : null,
      title: DionTextScroll(entry?.title ?? ''),
      child: SizedBox(
        width: context.width - 200,
        child: Row(
          children: [
            SizedBox(
              width: context.width / 2,
              child: EntryInfo(entry: entry!),
            ),
            isEntryDetailed(
              context: context,
              entry: entry!,
              isdetailed: (entry) => EpisodeListUI(entry: entry),
            ).expanded(),
          ],
        ),
      ),
    );
  }
}

Widget isEntryDetailed({
  required BuildContext context,
  required Entry entry,
  required Widget Function(EntryDetailed e) isdetailed,
  Widget Function()? isnt,
  bool shimmer = true,
}) {
  isnt ??= () => Container(color: Colors.white);
  if (entry is EntryDetailed) {
    return isdetailed(entry);
  }
  if (!shimmer) {
    return isnt();
  }
  return BoundsWidget(child: isnt()).applyShimmer(
    highlightColor: context.scaffoldBackgroundColor.lighten(20),
    baseColor: context.theme.scaffoldBackgroundColor,
  );
}
