import 'package:dionysos/data/library/library_query.dart';
import 'package:dionysos/data/settings/appsettings.dart';
import 'package:dionysos/service/extension.dart' hide TextStyle;
import 'package:dionysos/utils/media_type.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/widgets/dialog.dart';
import 'package:dionysos/widgets/dropdown/single_dropdown.dart';
import 'package:flutter/material.dart';

void showLibraryFilterPanel(
  BuildContext context, {
  required LibraryFilters filters,
  required LibrarySort sort,
  required ValueChanged<LibraryFilters> onFiltersChanged,
  required ValueChanged<LibrarySort> onSortChanged,
}) {
  showDialog(
    context: context,
    builder: (_) => DionDialog(
      child: _LibraryFilterPanel(
        initialFilters: filters,
        initialSort: sort,
        onFiltersChanged: onFiltersChanged,
        onSortChanged: onSortChanged,
      ),
    ),
  );
}

class _LibraryFilterPanel extends StatefulWidget {
  final LibraryFilters initialFilters;
  final LibrarySort initialSort;
  final ValueChanged<LibraryFilters> onFiltersChanged;
  final ValueChanged<LibrarySort> onSortChanged;

  const _LibraryFilterPanel({
    required this.initialFilters,
    required this.initialSort,
    required this.onFiltersChanged,
    required this.onSortChanged,
  });

  @override
  State<_LibraryFilterPanel> createState() => _LibraryFilterPanelState();
}

class _LibraryFilterPanelState extends State<_LibraryFilterPanel> {
  late LibraryFilters _filters = widget.initialFilters;
  late LibrarySort _sort = widget.initialSort;
  late final List<Extension> _extensions = locate<ExtensionService>()
      .getExtensions(
        // Entry-provider sources are the ones library entries can belong to.
        extfilter: (e) =>
            e.isenabled &&
            (e.getExtensionTypeOrNull<ExtensionType_EntryProvider>() != null ||
                e.data.extensionType.isEmpty),
      )
      .toList(growable: false);

  void _setFilters(LibraryFilters next) {
    setState(() => _filters = next);
    widget.onFiltersChanged(next);
  }

  void _setSort(LibrarySort next) {
    setState(() => _sort = next);
    settings.library.sortKey.value = next.key;
    settings.library.sortDescending.value = next.descending;
    widget.onSortChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Sort & filter',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_filters.isActive || _sort.isActive)
                  TextButton(
                    onPressed: () {
                      _setFilters(LibraryFilters.empty);
                      _setSort(const LibrarySort());
                    },
                    child: const Text('Reset'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _SortSection(sort: _sort, onChanged: _setSort),
            const _Divider(),
            _FilterSection(
              label: 'Media type',
              chips: [
                for (final mt in MediaType.values)
                  _Chip(
                    label: mt.name[0].toUpperCase() + mt.name.substring(1),
                    icon: mt.icon,
                    selected: _filters.mediaTypes.contains(mt),
                    onSelected: (sel) {
                      final next = Set<MediaType>.of(_filters.mediaTypes);
                      sel ? next.add(mt) : next.remove(mt);
                      _setFilters(_filters.copyWith(mediaTypes: next));
                    },
                  ),
              ],
            ),
            const _Divider(),
            _FilterSection(
              label: 'Status',
              chips: [
                for (final s in ReleaseStatus.values)
                  _Chip(
                    label: s.name[0].toUpperCase() + s.name.substring(1),
                    selected: _filters.statuses.contains(s),
                    onSelected: (sel) {
                      final next = Set<ReleaseStatus>.of(_filters.statuses);
                      sel ? next.add(s) : next.remove(s);
                      _setFilters(_filters.copyWith(statuses: next));
                    },
                  ),
              ],
            ),
            const _Divider(),
            // Only show the extension filter when there are sources to pick
            // from; otherwise the row would be an empty, confusing header.
            if (_extensions.isNotEmpty) ...[
              _FilterSection(
                label: 'Extension',
                chips: [
                  for (final e in _extensions)
                    _Chip(
                      label: e.name,
                      selected: _filters.extensionIds.contains(e.id),
                      onSelected: (sel) {
                        final next = Set<String>.of(_filters.extensionIds);
                        sel ? next.add(e.id) : next.remove(e.id);
                        _setFilters(_filters.copyWith(extensionIds: next));
                      },
                    ),
                ],
              ),
              const _Divider(),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tracked only'),
              subtitle: const Text('Entries with reading progress'),
              value: _filters.trackedOnly,
              onChanged: (v) => _setFilters(_filters.copyWith(trackedOnly: v)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortSection extends StatelessWidget {
  final LibrarySort sort;
  final ValueChanged<LibrarySort> onChanged;

  const _SortSection({required this.sort, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sort by', style: TextStyle(fontWeight: FontWeight.w600)),
        Row(
          children: [
            Expanded(
              child: DionDropdown<LibrarySortKey>(
                value: sort.key,
                items: [
                  for (final k in LibrarySortKey.values)
                    DionDropdownItem(value: k, label: k.label),
                ],
                onChanged: (k) {
                  if (k == null) return;
                  onChanged(sort.copyWith(key: k));
                },
              ),
            ),
            if (sort.key != LibrarySortKey.none)
              IconButton(
                tooltip: sort.descending ? 'Descending' : 'Ascending',
                onPressed: () =>
                    onChanged(sort.copyWith(descending: !sort.descending)),
                icon: Icon(
                  sort.descending ? Icons.south : Icons.north,
                  color: Colors.grey,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _FilterSection extends StatelessWidget {
  final String label;
  final List<Widget> chips;

  const _FilterSection({required this.label, required this.chips});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, children: chips),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _Chip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      avatar: icon == null ? null : Icon(icon, size: 18),
      selected: selected,
      onSelected: onSelected,
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1);
  }
}
