import 'dart:convert';

import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/settings/extension_setting.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/observer.dart';
import 'package:dionysos/utils/time.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/container/card.dart';
import 'package:dionysos/widgets/dynamic_grid.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/settings/dion_runtime.dart';
import 'package:flutter/material.dart' show Colors, Material;
import 'package:flutter/widgets.dart' hide Page;
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:awesome_extensions/awesome_extensions_dart.dart';

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
      if (slotentry.value.slotId == id) {
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

  Future<void> runAction(UIAction action) async {
    switch (action) {
      case final UIAction_SwapContent _:
        try {
          if (action.placeholder != null) {
            context.updateSlotContent(
              path,
              action.targetid,
              action.placeholder!,
            );
          }
          final res = await extension.event(
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
            throw Exception('Invalid event result type: ${res.runtimeType}');
          }
          context.updateSlotContent(path, action.targetid, res.customui);
        } catch (e, stack) {
          logger.e(
            'Failed to swap content at $path',
            error: e,
            stackTrace: stack,
          );
          //TODO: slot should be able to report errors
        }
      case final UIAction_Action action:
        try {
          final res=await extension.runAction(action.action);
          switch(res){
            case final EventResult_SwapContent _swap:
            logger.w('Action at $path returned null result');
            case final EventResult_DoAction doAction:
              await runAction(UIAction.action(action: doAction.action));
            case EventResult_Return():
              return;
            case EventResult_FeedUpdate():
              logger.w('Unexpected feed update result from action at $path');
            case null:
              logger.w('Action at $path returned null result');
          }
        } catch (e, stack) {
          logger.e(
            'Failed to perform action at $path',
            error: e,
            stackTrace: stack,
          );
        }
    }
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
        height: img.height?.toDouble(),
        width: img.width?.toDouble(),
      ),
      final CustomUI_Link link => Text(
        link.label ?? link.link,
        style: context.bodyMedium?.copyWith(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
      ).onTap(() => launchUrl(Uri.parse(link.link))),
      final CustomUI_Timestamp timestamp => switch (timestamp.display) {
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
        bottom: ClipRect(
          child: CustomUIWidget(
            ui: card.bottom,
            element: element.child('card/bottom'),
          ).paddingAll(8),
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
          await element.runAction(action);
        },
      ),
      final CustomUI_InlineSetting inlineSetting => CustomUISettingsView(
        data: inlineSetting,
        element: element.child('setting'),
      ),
      final CustomUI_Slot slot => CustomUISlot(
        data: slot,
        element: element.child('slot'),
        onMountAction: slot.onMount,
      ),
      CustomUI_Spinner() => const Center(child: DionProgressBar()),
    };
  }
}

class CustomUISettingsView extends StatefulWidget {
  final CustomUIElement element;
  final CustomUI_InlineSetting data;
  const CustomUISettingsView({
    super.key,
    required this.data,
    required this.element,
  });

  @override
  State<CustomUISettingsView> createState() => _CustomUISettingsViewState();
}

class _CustomUISettingsViewState extends State<CustomUISettingsView>
    with StateDisposeScopeMixin {
  late final Setting<dynamic, DionRuntimeSettingMetaData<dynamic>>? setting;

  @override
  void initState() {
    setting = widget.element.extension.settings[widget.data.settingKind]!
        .where((e) => e.metadata.id == widget.data.settingId)
        .firstOrNull;
    if (setting != null) {
      Observer(() {
        if (widget.data.onCommit == null) return;
        widget.element.runAction(widget.data.onCommit!);
      }, setting!).disposedBy(scope);
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (setting == null) {
      return Text('Setting ${widget.data.settingId} not found');
    }
    return Material(child: DionRuntimeSettingView(setting: setting!));
  }
}

class CustomUISlot extends StatefulWidget {
  final CustomUIElement element;
  final CustomUI_Slot data;
  final UIAction? onMountAction;
  const CustomUISlot({
    super.key,
    required this.data,
    required this.element,
    this.onMountAction,
  });

  @override
  State<CustomUISlot> createState() => _CustomUISlotState();
}

class _CustomUISlotState extends State<CustomUISlot> {
  late CustomUI content;

  @override
  void initState() {
    super.initState();
    if (widget.onMountAction != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await widget.element.runAction(widget.onMountAction!);
      });
    }
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
  late DataSourceController<(CustomUI, int)> controller;

  void initController() {
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
        if (res.hasnext == false){
          return Page.last(res.customui.map((e) => (e, index)).toList());
        }
        if (res.length!=null && res.length! <= index) {
          return Page.last(res.customui.map((e) => (e, index)).toList());
        }
        return Page.more(res.customui.map((e) => (e, index)).toList());
      }),
    ]);
    controller.requestMore();
  }

  @override
  void initState() {
    super.initState();
    initController();
  }

  @override
  void dispose() {
    widget.element.context.unregisterSlotContentHandler(widget.element.path);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CustomFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feed.data != widget.feed.data ||
        oldWidget.feed.event != widget.feed.event) {
      controller.dispose();
      initController();
    }
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
