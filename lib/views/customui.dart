import 'dart:async';
import 'dart:convert';

import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/entry/entry.dart';
import 'package:dionysos/data/settings/extension_setting.dart';
import 'package:dionysos/data/settings/settings.dart';
import 'package:dionysos/service/customui_store.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/service/extension.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/time.dart';
import 'package:dionysos/widgets/buttons/textbutton.dart';
import 'package:dionysos/widgets/container/card.dart';
import 'package:dionysos/widgets/dynamic_grid.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/settings/dion_runtime.dart';
import 'package:flutter/material.dart'
    show Colors, Material, TextEditingController, TextField;
import 'package:flutter/widgets.dart' hide Page;
import 'package:rdion_runtime/rdion_runtime.dart' as rust;
import 'package:url_launcher/url_launcher.dart';

class CustomUIElement {
  final String path;
  final Extension extension;
  const CustomUIElement({required this.path, required this.extension});

  factory CustomUIElement.init({required Extension extension}) =>
      CustomUIElement(path: '', extension: extension);

  CustomUIElement child(String childPath) =>
      CustomUIElement(extension: extension, path: '$path/$childPath');

  CustomUIStore get uiStore => extension.uiStore;

  Future<void> runInteraction(rust.Interaction? interaction) async {
    if (interaction == null) return;
    switch (interaction) {
      case final rust.Interaction_WriteKey write:
        await uiStore.set(write.key, write.value);
      case final rust.Interaction_Invoke invoke:
        try {
          await extension.event(
            event: rust.EventData.invoke(
              handler: invoke.handler,
              payload: invoke.payload,
            ),
          );
        } catch (e, st) {
          logger.e(
            'Trigger "${invoke.handler}" failed at $path',
            error: e,
            stackTrace: st,
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
        onPressed: () async {
          await element.runInteraction(button.onClick);
        },
        child: Text(button.label),
      ),
      final CustomUI_TextInput textInput => _CustomUITextInput(
        data: textInput,
        element: element.child('text'),
      ),
      final CustomUI_InlineSetting inlineSetting => CustomUISettingsView(
        data: inlineSetting,
        element: element.child('setting'),
      ),
      final CustomUI_Slot slot => CustomUISlot(
        data: slot,
        element: element.child('slot'),
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

class _CustomUISettingsViewState extends State<CustomUISettingsView> {
  Setting<dynamic, DionRuntimeSettingMetaData<dynamic>>? setting;

  @override
  void initState() {
    super.initState();
    setting = widget.element.extension.settings[widget.data.settingKind]!
        .where((e) => e.metadata.id == widget.data.settingId)
        .firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final s = setting;
    if (s == null) {
      return Text('Setting ${widget.data.settingId} not found');
    }
    return Material(child: DionRuntimeSettingView(setting: s));
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
  late CustomUI _content;
  _SlotError? _error;

  final List<(String, Object)> _storeTokens = [];
  final List<void Function()> _settingDisposers = [];

  bool _reloadScheduled = false;

  @override
  void initState() {
    super.initState();
    _content = widget.data.child;
    _bindSubscriptions();
    _fireLoadSlot();
  }

  @override
  void didUpdateWidget(covariant CustomUISlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.subscriptions != widget.data.subscriptions ||
        oldWidget.data.staticData != widget.data.staticData ||
        oldWidget.data.handler != widget.data.handler) {
      _unbindSubscriptions();
      _error = null;
      _content = widget.data.child;
      _bindSubscriptions();
      _fireLoadSlot();
    }
  }

  @override
  void dispose() {
    _unbindSubscriptions();
    super.dispose();
  }

  void _bindSubscriptions() {
    final ext = widget.element.extension;
    for (final sub in widget.data.subscriptions) {
      switch (sub.source) {
        case rust.SubscriptionSource_Store():
          _storeTokens.add((
            sub.key,
            ext.uiStore.subscribe(sub.key, _scheduleReload),
          ));
        case final rust.SubscriptionSource_Setting s:
          final setting = ext.settings[s.kind]
              ?.where((e) => e.metadata.id == sub.key)
              .firstOrNull;
          if (setting != null) {
            setting.addListener(_scheduleReload);
            _settingDisposers.add(
              () => setting.removeListener(_scheduleReload),
            );
          } else {
            // Fall back to the change bus so a Slot subscribed to a setting id
            // that has no live Setting object still rebuilds when it changes.
            final token = ext.settingChanges.subscribe(
              sub.key,
              _scheduleReload,
            );
            _settingDisposers.add(
              () => ext.settingChanges.unsubscribe(sub.key, token),
            );
          }
        case rust.SubscriptionSource_EntrySetting():
          final token = ext.settingChanges.subscribe(sub.key, _scheduleReload);
          _settingDisposers.add(
            () => ext.settingChanges.unsubscribe(sub.key, token),
          );
      }
    }
  }

  void _unbindSubscriptions() {
    final ext = widget.element.extension;
    for (final (key, token) in _storeTokens) {
      ext.uiStore.unsubscribe(key, token);
    }
    _storeTokens.clear();
    for (final disposer in _settingDisposers) {
      disposer();
    }
    _settingDisposers.clear();
    _reloadScheduled = false;
  }

  void _scheduleReload() {
    if (_reloadScheduled) return;
    _reloadScheduled = true;
    // Defer to the next microtask so two keys changing in the same tick produce
    // a single LoadSlot call with both updates visible.
    scheduleMicrotask(() {
      _reloadScheduled = false;
      if (!mounted) return;
      _fireLoadSlot();
    });
  }

  Future<Map<String, SlotValue>> _collectValues() async {
    final ext = widget.element.extension;
    final values = <String, SlotValue>{};
    for (final sub in widget.data.subscriptions) {
      switch (sub.source) {
        case rust.SubscriptionSource_Store():
          final v = ext.uiStore.get(sub.key);
          if (v != null) {
            values[sub.stateKey] = SlotValue.store(key: sub.key, value: v);
          }
        case final rust.SubscriptionSource_Setting s:
          final setting = ext.settings[s.kind]
              ?.where((e) => e.metadata.id == sub.key)
              .firstOrNull;
          if (setting != null) {
            final sv = switch (setting.value) {
              final String s => rust.SettingValue_String(data: s),
              final num n => rust.SettingValue_Number(data: n.toDouble()),
              final bool b => rust.SettingValue_Boolean(data: b),
              final List<String> l => rust.SettingValue_StringList(data: l),
              _ => throw UnimplementedError(
                'Unsupported setting value type: ${setting.value.runtimeType}',
              ),
            };
            values[sub.stateKey] = SlotValue.setting(value: sv);
          }
        case rust.SubscriptionSource_EntrySetting():
          final parsed = _parseEntrySettingKey(sub.key);

          if (parsed != null) {
            final entry = await locate<Database>().getSavedById(parsed.$1);
            if (ext.data.id == entry?.boundExtensionId) {
              final sv = entry?.extensionSettings[parsed.$2]?.value;
              if (sv != null) {
                values[sub.stateKey] = SlotValue.setting(value: sv);
              }
              continue;
            }
            final extid = ext.data.id;
            final entryExts = entry?.entryExtensions
                .where((ext) => ext.extensionId == extid)
                .firstOrNull
                ?.extensionSettings;
            if (entryExts != null) {
              final sv = entryExts[parsed.$2]?.value;
              if (sv != null) {
                values[sub.stateKey] = SlotValue.setting(value: sv);
                ;
              }
              continue;
            }
            final sourceExts = entry?.sourceExtensions
                .where((ext) => ext.extensionId == extid)
                .firstOrNull
                ?.extensionSettings;
            if (sourceExts != null) {
              final sv = sourceExts[parsed.$2]?.value;
              if (sv != null) {
                values[sub.stateKey] = SlotValue.setting(value: sv);
                ;
              }
              continue;
            }
          }
      }
    }
    return values;
  }

  Future<void> _fireLoadSlot() async {
    try {
      final values = await _collectValues();
      if (!mounted) return;
      final res = await widget.element.extension.event(
        event: rust.EventData.loadSlot(
          handler: widget.data.handler,
          staticData: widget.data.staticData,
          values: values,
        ),
      );
      if (!mounted) return;
      if (res is! rust.EventResult_SlotContent) {
        throw Exception(
          'Slot handler "${widget.data.handler}" returned '
          '${res?.runtimeType ?? "null"}; expected SlotContent',
        );
      }
      setState(() {
        _content = res.customui;
        _error = null;
      });
    } catch (e, st) {
      logger.e(
        'LoadSlot "${widget.data.handler}" failed at ${widget.element.path}',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      setState(() {
        _error = _SlotError(e, st);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final err = _error;
    if (err != null) {
      return ErrorDisplay(e: err.error, s: err.stackTrace);
    }
    return CustomUIWidget(ui: _content, element: widget.element.child('inner'));
  }
}

class _SlotError {
  final Object error;
  final StackTrace stackTrace;
  _SlotError(this.error, this.stackTrace);
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
          event: rust.EventData.loadPage(
            handler: widget.feed.handler,
            data: widget.feed.data,
            page: index,
          ),
        );
        if (res is! rust.EventResult_FeedPage) {
          throw Exception(
            'Feed handler "${widget.feed.handler}" returned '
            '${res?.runtimeType ?? "null"}; expected FeedPage',
          );
        }
        final items = res.items.map((e) => (e, index)).toList();
        return res.hasMore ? Page.more(items) : Page.last(items);
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
    controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CustomFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feed.data != widget.feed.data ||
        oldWidget.feed.handler != widget.feed.handler) {
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

class _CustomUITextInput extends StatefulWidget {
  final CustomUI_TextInput data;
  final CustomUIElement element;
  const _CustomUITextInput({required this.data, required this.element});

  @override
  State<_CustomUITextInput> createState() => _CustomUITextInputState();
}

class _CustomUITextInputState extends State<_CustomUITextInput> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.data.initial);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _fireChange() {
    final interaction = widget.data.onChange;
    if (interaction == null) return;
    widget.element.runInteraction(_withValue(interaction, _controller.text));
  }

  void _fireCommit() {
    _debounce?.cancel();
    final interaction = widget.data.onCommit;
    if (interaction == null) return;
    widget.element.runInteraction(_withValue(interaction, _controller.text));
  }

  rust.Interaction _withValue(rust.Interaction interaction, String text) {
    final encoded = jsonEncode(text);
    return switch (interaction) {
      final rust.Interaction_WriteKey w => rust.Interaction.writeKey(
        key: w.key,
        value: encoded,
      ),
      final rust.Interaction_Invoke i => rust.Interaction.invoke(
        handler: i.handler,
        payload: encoded,
      ),
    };
  }

  void _onChange() {
    _debounce?.cancel();
    final ms = widget.data.debounceMs ?? 0;
    if (ms <= 0) {
      _fireChange();
      return;
    }
    _debounce = Timer(Duration(milliseconds: ms), _fireChange);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: TextField(
        controller: _controller,
        onChanged: (_) => _onChange(),
        onSubmitted: (_) => _fireCommit(),
        onTapOutside: (_) => _fireCommit(),
      ),
    );
  }
}

(EntryId, String)? _parseEntrySettingKey(String key) {
  final idx = key.indexOf(':');
  if (idx <= 0 || idx >= key.length - 1) return null;
  return (EntryId(uid: key.substring(0, idx)), key.substring(idx + 1));
}
