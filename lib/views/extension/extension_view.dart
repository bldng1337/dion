import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:dionysos/service/extension.dart' hide Alignment,ContainerType,CrossAxisAlignment,EdgeInsets,MainAxisAlignment,MainAxisSize,StackFit,TextStyle,WrapAlignment;
import 'package:dionysos/utils/autoadd.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/storage.dart';
import 'package:dionysos/utils/toast.dart';
import 'package:dionysos/views/extension/account_view.dart';
import 'package:dionysos/views/extension/permission_view.dart';
import 'package:dionysos/widgets/container/badge.dart';
import 'package:dionysos/widgets/dialog.dart';
import 'package:dionysos/widgets/dropdown/multi_dropdown.dart';
import 'package:dionysos/widgets/errordisplay.dart';
import 'package:dionysos/widgets/foldabletext.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/progress.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:dionysos/widgets/settings/dion_runtime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';
import 'package:rdion_runtime/rdion_runtime.dart' as rust;

class ExtensionView extends StatefulWidget {
  const ExtensionView({super.key});

  @override
  _ExtensionViewState createState() => _ExtensionViewState();
}

class _ExtensionViewState extends State<ExtensionView>
    with StateDisposeScopeMixin {
  Extension? extension;
  Object? error;
  int? _extensionSize;

  @override
  void initState() {
    scope.addDispose(() async {
      await extension?.save();
    });
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final ext = locate<ExtensionService>().getExtension(
        GoRouterState.of(context).pathParameters['id']!,
      );
      setState(() {
        extension = ext;
      });
      _calculateExtensionSize();
    } catch (e) {
      error = e;
    }
  }

  Future<void> _calculateExtensionSize() async {
    if (extension == null) return;
    try {
      final sourceExt = locate<ExtensionService>();
      final extensionPath = await sourceExt.getExtensionStorageDir(extension!);
      final size = await getDirectorySize(extensionPath);
      if (mounted) {
        setState(() {
          _extensionSize = size;
        });
      }
    } catch (e) {
      logger.w('Failed to calculate extension size', error: e);
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
                          extension!.data.version,
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
                  if (_extensionSize != null)
                    Text(
                      'Storage: ${formatBytes(_extensionSize!)}',
                      style: context.bodySmall,
                    ),
                ],
              ).paddingAll(10),
            ],
          ).paddingAll(30),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (extension!.data.desc != null &&
                      extension!.data.desc!.isNotEmpty) ...[
                    Foldabletext(
                      extension!.data.desc ?? '',
                      style: context.bodyMedium,
                    ),
                    const Divider(),
                  ],
                  // Permissions section
                  PermissionView(extension: extension!),
                  const Divider(),
                  // Accounts section
                  AccountsView(extension: extension!),
                  const Divider(),
                  // Auto-add rules section (EntryProcessor extensions only)
                  if (extension!
                          .getExtensionTypeOrNull<
                            rust.ExtensionType_EntryProcessor
                          >() !=
                      null) ...[
                    AutoAddSection(extension: extension!),
                    const Divider(),
                  ],
                  // Settings section
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

class AutoAddSection extends StatefulWidget {
  final Extension extension;
  const AutoAddSection({super.key, required this.extension});

  @override
  State<AutoAddSection> createState() => _AutoAddSectionState();
}

class _AutoAddSectionState extends State<AutoAddSection>
    with StateDisposeScopeMixin {
  late final MultiDropdownController<String> _controller;

  static const _mediaTypeItems = [
    (rust.MediaType.book, 'Books'),
    (rust.MediaType.comic, 'Comics'),
    (rust.MediaType.video, 'Video'),
    (rust.MediaType.audio, 'Audio'),
  ];

  @override
  void initState() {
    super.initState();
    _controller = MultiDropdownController<String>()..disposedBy(scope);
    _controller.setItems([
      MultiDropdownItem<String>(value: autoAddTokenAll, label: 'All sources'),
      for (final (type, label) in _mediaTypeItems)
        MultiDropdownItem<String>(value: autoAddTokenForMediaType(type), label: label),
      ...locate<ExtensionService>()
          .getExtensions()
          .where(
            (ext) =>
                ext.id != widget.extension.id &&
                ext.getExtensionTypeOrNull<rust.ExtensionType_EntryProvider>() !=
                    null,
          )
          .map(
            (ext) => MultiDropdownItem<String>(
              value: autoAddTokenForExtension(ext),
              label: ext.name,
            ),
          ),
    ]);
    _controller.selectWhere(
      (item) => widget.extension.meta.autoAddRules.contains(item.value),
    );
  }

  List<String> _enforceExclusivity(List<String> selection) {
    if (selection.length < 2) return selection;
    final hasAll = selection.contains(autoAddTokenAll);
    final hadAll = widget.extension.meta.autoAddRules.contains(autoAddTokenAll);
    if (hasAll && !hadAll) return [autoAddTokenAll];
    if (hasAll && hadAll) return selection.where((e) => e != autoAddTokenAll).toList();
    return selection;
  }

  Future<void> _onSelectionChange(List<String> selection) async {
    final rules = _enforceExclusivity(selection);
    // Reflect exclusivity back into the dropdown state.
    _controller.deselectWhere((item) => !rules.contains(item.value));

    final oldRules = widget.extension.meta.autoAddRules;
    final unchanged =
        oldRules.length == rules.length && oldRules.toSet().containsAll(rules);
    if (unchanged) return;
    widget.extension.meta = widget.extension.meta.copyWith(autoAddRules: rules);

    final delta = await newlyMatchingEntries(widget.extension, oldRules);
    if (!mounted || delta.isEmpty) return;
    final apply = await showDialog<bool>(
      context: context,
      builder: (context) => DionAlertDialog(
        title: const Text('Add to existing entries?'),
        content: Text(
          "${widget.extension.name}'s auto-add rule now matches "
          '${delta.length} library ${delta.length == 1 ? 'entry' : 'entries'} '
          'it is not attached to yet. Add it to them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (apply != true) return;
    final count = await backfillAutoAdd(widget.extension);
    logger.i(
      'Backfilled ${widget.extension.id} into $count entries after rule change',
    );
    showToast(
      'Added ${widget.extension.name} to $count '
      '${count == 1 ? 'entry' : 'entries'}',
      ToastKind.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Auto-Add', style: context.titleMedium),
              const SizedBox(width: 8),
              DionBadge(
                child: Text(
                  'Entry Extensions',
                  style: context.bodySmall,
                ),
              ),
            ],
          ).paddingOnly(bottom: 4),
          Text(
            'Automatically add ${widget.extension.name} when saving entries '
            'from the selected sources. Leave empty to never add it '
            'automatically.',
            style: context.bodySmall?.copyWith(
              color: context.theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ).paddingOnly(bottom: 8),
          DionMultiDropdown<String>(
            controller: _controller,
            defaultItem: Text(
              'Never add automatically',
              style: context.bodyMedium?.copyWith(
                color: context.theme.colorScheme.onSurface.withValues(
                  alpha: 0.5,
                ),
              ),
            ),
            onSelectionChange: _onSelectionChange,
          ),
        ],
      ),
    );
  }
}
