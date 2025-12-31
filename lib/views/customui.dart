import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/time.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/container/card.dart';
import 'package:dionysos/widgets/dynamic_grid.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/settings/dion_runtime.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart' hide Page;
import 'package:url_launcher/url_launcher.dart';

class Slot {
  final Function(CustomUI) handler;
  final String slotId;
  Slot({required this.slotId, required this.handler});
}

class CustomUIContext {
  final Map<String, Slot> _slotContentHandlers = {};
  CustomUIContext();

  void registerSlotContentHandler(String path, Slot slot) {
    _slotContentHandlers[path] = slot;
  }

  void unregisterSlotContentHandler(String path) {
    _slotContentHandlers.remove(path);
  }

  void updateSlotContent(String path, String id, CustomUI content) {
    //TODO: A real tree would probably be faster but this is easier and should be fine for now
    for (final slotentry in _slotContentHandlers.entries) {
      if (slotentry.key.startsWith(path) && slotentry.value.slotId == id) {
        slotentry.value.handler(content);
      }
    }
  }
}

class CustomUIElement {
  final String path;
  final Extension extension;
  final CustomUIContext context;
  CustomUIElement({
    required this.path,
    required this.extension,
    required this.context,
  });
  CustomUIElement.init({required this.extension})
    : path = '',
      context = CustomUIContext();
  CustomUIElement child(String childPath) {
    return CustomUIElement(
      extension: extension,
      path: '$path/$childPath',
      context: context,
    );
  }
}

class CustomUIWidget extends StatelessWidget {
  final CustomUIElement element;
  final CustomUI? ui;

  const CustomUIWidget({super.key, this.ui, required this.element});
  factory CustomUIWidget.fromUI({
    required CustomUI ui,
    required Extension extension,
  }) {
    return CustomUIWidget(
      ui: ui,
      element: CustomUIElement.init(extension: extension),
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (ui) {
      null => nil,
      final CustomUI_Text text => Text(text.text),
      final CustomUI_Image img => DionImage(
        imageUrl: img.image.url,
        httpHeaders: img.image.header,
      ),
      final CustomUI_Link link => Text(
        link.label ?? link.link,
        style: context.bodyMedium?.copyWith(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
      ).onTap(() => launchUrl(Uri.parse(link.link))),
      final CustomUI_TimeStamp timestamp => switch (timestamp.display) {
        TimestampType.relative => Text(
          DateTime.tryParse(timestamp.timestamp)?.formatrelative() ?? '',
        ),
        TimestampType.absolute => Text(
          DateTime.tryParse(timestamp.timestamp)?.toString() ?? '',
        ),
      },
      final CustomUI_EntryCard entryCard => EntryCard(
        entry: EntryImpl(entryCard.entry, element.extension.id),
      ),
      final CustomUI_Column column => SingleChildScrollView(
        child: Column(
          children: column.children.indexed
              .map(
                (data) => CustomUIWidget(
                  ui: data.$2,
                  element: element.child('column/${data.$1}'),
                ),
              )
              .toList(),
        ),
      ),
      final CustomUI_Row row => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: row.children.indexed
              .map(
                (data) => CustomUIWidget(
                  ui: data.$2,
                  element: element.child('row/${data.$1}'),
                ),
              )
              .toList(),
        ),
      ),
      final CustomUI_Card card => Card(
        imageUrl: card.image.url,
        httpHeaders: card.image.header,
        bottom: CustomUIWidget(
          ui: card.bottom,
          element: element.child('card/bottom'),
        ),
        leadingBadges: [
          CustomUIWidget(ui: card.top, element: element.child('card/top')),
        ],
      ),
      final CustomUI_Feed feed => CustomFeed(
        feed: feed,
        element: element.child('feed'),
      ),
      final CustomUI_Button button => DionTextbutton(
        child: Text(button.label),
        onPressed: () async {
          final action = button.onClick;
          if (action == null) return;
          if (action is UIAction_SwapContent) {
            try {
              if (action.placeholder != null) {
                element.context.updateSlotContent(
                  element.path,
                  action.targetid,
                  action.placeholder!,
                );
              }
              final res = await element.extension.event(
                event: EventData.swapContent(
                  data: action.data,
                  event: action.event,
                  targetid: action.targetid,
                ),
              );
              if (res == null) {
                return;
              }
              if (res is! EventResult_SwapContent) {
                throw Exception(
                  'Invalid event result type: ${res.runtimeType}',
                );
              }
              element.context.updateSlotContent(
                element.path,
                action.targetid,
                res.customui,
              );
            } catch (e, stack) {
              logger.e(
                'Failed to swap content at ${element.path}',
                error: e,
                stackTrace: stack,
              );
              //TODO: slot should be able to report errors
            }
            return;
          }
          //TODO: handle other actions
        },
      ),
      final CustomUI_InlineSetting inlineSetting => DionRuntimeSettingView(
        setting: element.extension.settings[inlineSetting.settingKind]!
            .firstWhere((e) => e.metadata.id == inlineSetting.settingId),
      ), //TODO Error handling
      final CustomUI_Slot slot => CustomUISlot(
        data: slot,
        element: element.child('slot'),
      ),
    };
  }
}

class CustomUISlot extends StatefulWidget {
  final CustomUIElement element;
  final CustomUI_Slot data;
  const CustomUISlot({super.key, required this.data, required this.element});

  @override
  State<CustomUISlot> createState() => _CustomUISlotState();
}

class _CustomUISlotState extends State<CustomUISlot> {
  late CustomUI content;

  @override
  void initState() {
    super.initState();
    content = widget.data.child;
    widget.element.context.registerSlotContentHandler(
      widget.element.path,
      Slot(
        slotId: widget.data.id,
        handler: (CustomUI newContent) {
          setState(() {
            content = newContent;
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    widget.element.context.unregisterSlotContentHandler(widget.element.path);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CustomUISlot oldWidget) {
    if (oldWidget.data.child != widget.data.child) {
      setState(() {
        content = widget.data.child;
      });
    }
    if (oldWidget.element.context != widget.element.context) {
      oldWidget.element.context.unregisterSlotContentHandler(
        oldWidget.element.path,
      );
      widget.element.context.registerSlotContentHandler(
        widget.element.path,
        Slot(
          slotId: widget.data.id,
          handler: (CustomUI newContent) {
            setState(() {
              content = newContent;
            });
          },
        ),
      );
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return CustomUIWidget(ui: content, element: widget.element.child('inner'));
  }
}

class CustomFeed extends StatefulWidget {
  final CustomUIElement element;
  final CustomUI_Feed feed;
  const CustomFeed({super.key, required this.feed, required this.element});

  @override
  State<CustomFeed> createState() => _CustomFeedState();
}

class _CustomFeedState extends State<CustomFeed> {
  late final DataSourceController<(CustomUI, int)> controller;

  @override
  void initState() {
    super.initState();
    controller = DataSourceController([
      PageAsyncSource((index) async {
        final res = await widget.element.extension.event(
          event: EventData.feedUpdate(
            data: widget.feed.data,
            event: widget.feed.event,
            page: index,
          ),
        );
        if (res == null) {
          return Page.empty();
        }
        if (res is! EventResult_FeedUpdate) {
          throw Exception('Invalid event result type: ${res.runtimeType}');
        }
        if (!(res.hasnext ?? true) || (res.length ?? 0) >= index) {
          return Page.last(res.customui.map((e) => (e, index)).toList());
        }
        return Page.more(res.customui.map((e) => (e, index)).toList());
      }),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return DynamicGrid(
      controller: controller,
      itemBuilder: (context, item) => CustomUIWidget(
        element: widget.element.child('${item.$2}'),
        ui: item.$1,
      ),
    );
  }
}
