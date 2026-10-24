import 'dart:async';
import 'dart:math' as math;

import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/data/source.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/utils/design_tokens.dart';
import 'package:dionysos/utils/log.dart';
import 'package:dionysos/utils/media_type.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/views/note/wiki_link.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/note_markdown.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show RenderBox, RenderEditable, RenderObject;
import 'package:flutter/services.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:go_router/go_router.dart';

Future<void> openChapterNote(BuildContext context, EpisodePath path) async {
  final entry = path.entry;
  if (entry is! EntrySaved || !context.mounted) return;
  await context.push('/note', extra: [entry, path.episodenumber]);
}

class NoteEditorPage extends StatefulWidget {
  final EntrySaved entry;

  /// null for the entry-level note.
  final int? episodeIndex;

  const NoteEditorPage({super.key, required this.entry, this.episodeIndex});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage>
    with StateDisposeScopeMixin {
  late String? _persistedNote = _readNote();
  late final TextEditingController _controller = TextEditingController(
    text: _persistedNote ?? '',
  )..disposedBy(scope);
  Timer? _saveDebounce;
  Timer? _suggestDebounce;
  bool _preview = false;

  List<_NoteSuggestion> _suggestions = const [];
  int _selectedSuggestion = 0;
  bool _suggestionsLoading = false;
  int _requestId = 0;

  final GlobalKey _textFieldKey = GlobalKey();
  final GlobalKey _editorStackKey = GlobalKey();

  static const double _panelMaxHeight = 240;
  static const double _panelMaxWidth = 520;

  String? _readNote() => widget.episodeIndex == null
      ? widget.entry.note
      : widget.entry.getEpisodeData(widget.episodeIndex!).note;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _suggestDebounce?.cancel();
    _save();
    super.dispose();
  }

  void _onTextChanged() {
    _scheduleSave();
    _updateSuggestions();
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 800), _save);
  }

  void _save() {
    final text = _controller.text.trim().isEmpty ? null : _controller.text;
    if (text == _persistedNote) return;
    _persistedNote = text;
    if (widget.episodeIndex == null) {
      widget.entry.note = text;
    } else {
      widget.entry.getEpisodeData(widget.episodeIndex!).note = text;
    }
    unawaited(widget.entry.save());
  }

  /// The open `[[token` before the cursor, as (index of '[[' , token text),
  /// or null when the cursor is not inside a fresh link.
  (int, String)? get _openLinkToken {
    final selection = _controller.selection;
    if (!selection.isValid || !selection.isCollapsed) return null;
    final cursor = selection.baseOffset;
    if (cursor < 2) return null;
    final beforeCursor = _controller.text.substring(0, cursor);
    final start = beforeCursor.lastIndexOf('[[');
    if (start < 0) return null;
    final token = beforeCursor.substring(start + 2);
    if (token.contains(']]') || token.contains('\n')) return null;
    return (start, token);
  }

  void _updateSuggestions() {
    final token = _openLinkToken;
    if (token == null) {
      _hideSuggestions();
      return;
    }
    final query = token.$2;
    final hash = query.indexOf('#');
    if (hash < 0 || hash == 0) {
      // Chapters of this entry: for `[[q` mixed with entries, for `[[#q`
      // chapter-only.
      final chapterQuery = hash == 0 ? query.substring(1) : query;
      final chapters = _chapterSuggestions(
        widget.entry,
        chapterQuery,
        insertPrefix: '',
        subtitle: widget.entry.title,
      );
      setState(() {
        _suggestions = hash == 0
            ? chapters.take(8).toList()
            : chapters.take(4).toList();
        _selectedSuggestion = 0;
        _suggestionsLoading = hash < 0;
      });
      if (hash < 0) {
        _debounceSuggestions(() => _queryEntries(query));
      }
      return;
    }
    // `[[Title#q`: suggest chapters of the referenced entry.
    final titlePart = query.substring(0, hash).trim();
    final chapterQuery = query.substring(hash + 1);
    setState(() {
      _suggestions = const [];
      _selectedSuggestion = 0;
      _suggestionsLoading = true;
    });
    _debounceSuggestions(() => _queryChaptersOfEntry(titlePart, chapterQuery));
  }

  void _debounceSuggestions(void Function() query) {
    _suggestDebounce?.cancel();
    _suggestDebounce = Timer(const Duration(milliseconds: 200), query);
  }

  List<_NoteSuggestion> _chapterSuggestions(
    EntrySaved entry,
    String query, {
    required String insertPrefix,
    String? subtitle,
  }) {
    final lower = query.trim().toLowerCase();
    return [
      for (final episode in entry.episodes)
        if (lower.isEmpty || episode.name.toLowerCase().contains(lower))
          _NoteSuggestion(
            insert: '$insertPrefix#${episode.name}',
            label: episode.name,
            icon: Icons.format_list_numbered_outlined,
            subtitle: subtitle,
          ),
    ];
  }

  Future<void> _queryEntries(String query) async {
    final request = ++_requestId;
    try {
      final db = locate<Database>();
      final results = <_NoteSuggestion>[];
      if (query.trim().isEmpty) {
        await for (final entry in db.queryEntries(page: 0, limit: 8)) {
          results.add(
            _NoteSuggestion(
              insert: entry.title,
              label: entry.title,
              icon: entry.mediaType.icon,
            ),
          );
        }
      } else {
        await for (final entry in db.searchEntries(query, 0, 8)) {
          results.add(
            _NoteSuggestion(
              insert: entry.title,
              label: entry.title,
              icon: entry.mediaType.icon,
            ),
          );
        }
      }
      if (!mounted || request != _requestId) return;
      setState(() {
        _suggestions = [..._suggestions, ...results];
        _suggestionsLoading = false;
      });
    } catch (e, stack) {
      logger.e(
        'Error searching entries for note link',
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<void> _queryChaptersOfEntry(
    String titlePart,
    String chapterQuery,
  ) async {
    final request = ++_requestId;
    final entry = await findEntryByTitle(titlePart);
    if (!mounted || request != _requestId) return;
    setState(() {
      _suggestions = entry == null
          ? const []
          : _chapterSuggestions(
              entry,
              chapterQuery,
              insertPrefix: entry.title,
            ).take(8).toList();
      _suggestionsLoading = false;
    });
  }

  void _hideSuggestions() {
    _suggestDebounce?.cancel();
    if (_suggestions.isEmpty && !_suggestionsLoading) return;
    setState(() {
      _suggestions = const [];
      _suggestionsLoading = false;
      _selectedSuggestion = 0;
    });
  }

  void _acceptSuggestion(_NoteSuggestion suggestion) {
    final token = _openLinkToken;
    if (token == null) {
      _hideSuggestions();
      return;
    }
    final cursor = _controller.selection.baseOffset;
    // Swallow the closing brackets of an already-closed link so completing
    // inside e.g. `[[Title#]]` doesn't leave `]]]]` behind.
    var end = cursor;
    if (_controller.text.startsWith(']]', end)) {
      end += 2;
    }
    final replacement = '[[${suggestion.insert}]]';
    _controller.value = TextEditingValue(
      text: _controller.text.replaceRange(token.$1, end, replacement),
      selection: TextSelection.collapsed(offset: token.$1 + replacement.length),
    );
    _hideSuggestions();
  }

  KeyEventResult _handleEditorKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || _openLinkToken == null) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_suggestions.isEmpty) return KeyEventResult.ignored;
      setState(() {
        _selectedSuggestion = (_selectedSuggestion + 1) % _suggestions.length;
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_suggestions.isEmpty) return KeyEventResult.ignored;
      setState(() {
        _selectedSuggestion = (_selectedSuggestion - 1) % _suggestions.length;
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (_suggestions.isEmpty) return KeyEventResult.ignored;
      _acceptSuggestion(_suggestions[_selectedSuggestion]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _hideSuggestions();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final episodeIndex = widget.episodeIndex;
    final chapterName = episodeIndex == null
        ? null
        : widget.entry.episodes[episodeIndex].name;
    return NavScaff(
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: context.isCompactWindow
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Text('Note', style: context.titleMedium),
          Text(
            chapterName ?? widget.entry.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.bodySmall?.copyWith(
              color: context.theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
      actions: [
        DionIconbutton(
          tooltip: _preview ? 'Edit' : 'Preview',
          icon: Icon(
            _preview ? Icons.edit_outlined : Icons.visibility_outlined,
            size: 18,
          ),
          onPressed: () {
            _save();
            setState(() {
              _preview = !_preview;
            });
          },
        ),
      ],
      child: _preview
          ? SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: DionSpacing.lg,
                vertical: DionSpacing.md,
              ),
              child: NoteMarkdown(
                data: _controller.text,
                onWikiLink: (target) =>
                    openWikiLink(context, widget.entry, target),
              ),
            )
          : _buildEditor(context),
    );
  }

  Widget _buildEditor(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        key: _editorStackKey,
        children: [
          Focus(
            onKeyEvent: _handleEditorKey,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: DionSpacing.lg),
              child: TextField(
                key: _textFieldKey,
                controller: _controller,
                autofocus: true,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                style: context.bodyMedium?.copyWith(height: 1.6),
                cursorColor: context.theme.colorScheme.primary,
                decoration: InputDecoration(
                  hintText:
                      'Write in Markdown… type [[ to link a chapter or entry',
                  hintStyle: context.bodyMedium?.copyWith(
                    color: context.theme.colorScheme.onSurface.withValues(
                      alpha: 0.35,
                    ),
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          if (_openLinkToken != null)
            _buildSuggestionPanel(context, constraints),
        ],
      ),
    );
  }

  /// Caret rect in editor-stack coordinates; falls back to the bottom of the
  /// editor when the render objects are not measurable yet.
  Rect _caretRect(BoxConstraints constraints) {
    final stackContext = _editorStackKey.currentContext;
    final fieldContext = _textFieldKey.currentContext;
    final stackBox = stackContext?.findRenderObject();
    if (stackContext == null ||
        fieldContext == null ||
        stackBox is! RenderBox ||
        !stackBox.hasSize) {
      return Rect.fromLTWH(DionSpacing.lg, constraints.maxHeight, 0, 0);
    }
    final editable = _findRenderEditable(fieldContext.findRenderObject());
    if (editable == null || !editable.hasSize) {
      return Rect.fromLTWH(DionSpacing.lg, constraints.maxHeight, 0, 0);
    }
    final cursor = _controller.selection.baseOffset.clamp(
      0,
      _controller.text.length,
    );
    final caret = editable.getLocalRectForCaret(TextPosition(offset: cursor));
    final topLeft = editable.localToGlobal(caret.topLeft, ancestor: stackBox);
    return Rect.fromLTWH(topLeft.dx, topLeft.dy, caret.width, caret.height);
  }

  RenderEditable? _findRenderEditable(RenderObject? root) {
    if (root is RenderEditable) return root;
    if (root == null) return null;
    RenderEditable? result;
    root.visitChildren((child) {
      result ??= _findRenderEditable(child);
    });
    return result;
  }

  Widget _buildSuggestionPanel(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final caret = _caretRect(constraints);
    final panelWidth = math.max(
      120.0,
      math.min(_panelMaxWidth, constraints.maxWidth - 2 * DionSpacing.lg),
    );
    final left = caret.left
        .clamp(
          DionSpacing.lg,
          math.max(
            DionSpacing.lg,
            constraints.maxWidth - panelWidth - DionSpacing.lg,
          ),
        )
        .toDouble();
    // Prefer directly below the caret line; flip above it when there is no
    // room, and clamp inside the editor so the panel never leaves the screen.
    final top =
        (caret.bottom + DionSpacing.xs + _panelMaxHeight <=
                    constraints.maxHeight
                ? caret.bottom + DionSpacing.xs
                : caret.top - DionSpacing.xs - _panelMaxHeight)
            .clamp(0.0, math.max(0.0, constraints.maxHeight - _panelMaxHeight))
            .toDouble();
    return Positioned(
      left: left,
      top: top,
      width: panelWidth,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: _panelMaxHeight),
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(DionRadius.md),
          color: context.theme.colorScheme.surfaceContainerHighest,
          clipBehavior: Clip.antiAlias,
          child: _suggestionsLoading && _suggestions.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(DionSpacing.lg),
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : _suggestions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(DionSpacing.lg),
                  child: Text(
                    'No matches',
                    style: context.bodySmall?.copyWith(
                      color: context.theme.colorScheme.onSurface.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: DionSpacing.xs),
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    final selected = index == _selectedSuggestion;
                    return InkWell(
                      onTap: () => _acceptSuggestion(suggestion),
                      child: ColoredBox(
                        color: selected
                            ? context.theme.colorScheme.primary.withValues(
                                alpha: 0.12,
                              )
                            : Colors.transparent,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DionSpacing.md,
                            vertical: DionSpacing.sm,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                suggestion.icon,
                                size: 16,
                                color: context.theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: DionSpacing.sm),
                              Expanded(
                                child: Text(
                                  suggestion.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.bodyMedium,
                                ),
                              ),
                              if (suggestion.subtitle != null) ...[
                                const SizedBox(width: DionSpacing.sm),
                                Flexible(
                                  child: Text(
                                    suggestion.subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.bodySmall?.copyWith(
                                      color: context.theme.colorScheme.onSurface
                                          .withValues(alpha: 0.45),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _NoteSuggestion {
  /// The text inserted between the `[[` `]]` brackets.
  final String insert;
  final String label;
  final IconData icon;
  final String? subtitle;

  const _NoteSuggestion({
    required this.insert,
    required this.label,
    required this.icon,
    this.subtitle,
  });
}
