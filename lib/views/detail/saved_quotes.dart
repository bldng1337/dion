import 'package:awesome_extensions/awesome_extensions.dart' hide NavigatorExt;
import 'package:dionysos/data/entry/entry_saved.dart';
import 'package:dionysos/service/database.dart';
import 'package:dionysos/utils/service.dart';
import 'package:dionysos/utils/time.dart';
import 'package:dionysos/widgets/buttons/iconbutton.dart';
import 'package:dionysos/widgets/image.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/material.dart';

class SavedQuotesView extends StatefulWidget {
  final EntrySaved entry;
  const SavedQuotesView({super.key, required this.entry});

  @override
  State<SavedQuotesView> createState() => _SavedQuotesViewState();
}

class _SavedQuotesViewState extends State<SavedQuotesView> {
  List<(int, EpisodeData)> get _episodesWithContent {
    final entry = widget.entry;
    final result = <(int, EpisodeData)>[];
    final count = entry.episodedata.length;
    for (int i = 0; i < count; i++) {
      final data = entry.episodedata[i];
      if (data.quotes.isNotEmpty || data.images.isNotEmpty) {
        result.add((i, data));
      }
    }
    return result;
  }

  bool get _hasAnyContent =>
      widget.entry.episodedata.any(
        (e) => e.quotes.isNotEmpty || e.images.isNotEmpty,
      );

  Future<void> _deleteQuote(int episodeIndex, SavedQuote quote) async {
    setState(() {
      widget.entry.getEpisodeData(episodeIndex).quotes.remove(quote);
    });
    await widget.entry.save();
  }

  Future<void> _deleteImage(int episodeIndex, SavedImage image) async {
    setState(() {
      widget.entry.getEpisodeData(episodeIndex).images.remove(image);
    });
    await widget.entry.save();
  }

  @override
  Widget build(BuildContext context) {
    return NavScaff(
      title: const Text('Saved Quotes & Images'),
      child: ListenableBuilder(
        listenable: locate<Database>().getListenable(DBEvent.entryUpdated),
        builder: (context, _) {
          if (!_hasAnyContent) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.format_quote,
                    size: 48,
                    color: context.theme.colorScheme.onSurface.withValues(
                      alpha: 0.3,
                    ),
                  ).paddingOnly(bottom: 12),
                  Text(
                    'No saved quotes or images yet',
                    style: context.bodyLarge?.copyWith(
                      color: context.theme.colorScheme.onSurface.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ).paddingOnly(bottom: 6),
                  Text(
                    'Select text in the reader or long-press an image to save.',
                    textAlign: TextAlign.center,
                    style: context.bodySmall?.copyWith(
                      color: context.theme.colorScheme.onSurface.withValues(
                        alpha: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          final episodes = _episodesWithContent;
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              for (final (index, data) in episodes) ...[
                _buildEpisodeHeader(context, index),
                for (final quote in data.quotes.toList())
                  _buildQuoteCard(context, index, quote),
                if (data.images.isNotEmpty)
                  _buildImageGrid(context, index, data),
              ],
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEpisodeHeader(BuildContext context, int episodeIndex) {
    final episodes = widget.entry.episodes;
    final name = episodeIndex < episodes.length
        ? episodes[episodeIndex].name
        : 'Episode ${episodeIndex + 1}';
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        name,
        style: context.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: context.theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    ).paddingOnly(bottom: 10);
  }

  Widget _buildQuoteCard(
    BuildContext context,
    int episodeIndex,
    SavedQuote quote,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.4,
        ),
        borderRadius: BorderRadius.circular(3),
        border: Border(
          left: BorderSide(
            color: context.theme.colorScheme.primary.withValues(alpha: 0.6),
            width: 3,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"${quote.text}"',
                  style: context.bodyMedium?.copyWith(
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                    color: context.theme.colorScheme.onSurface.withValues(
                      alpha: 0.85,
                    ),
                  ),
                ).paddingOnly(bottom: 6),
                Text(
                  quote.savedAt.formatrelative(),
                  style: context.labelSmall?.copyWith(
                    color: context.theme.colorScheme.onSurface.withValues(
                      alpha: 0.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          DionIconbutton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () => _deleteQuote(episodeIndex, quote),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid(
    BuildContext context,
    int episodeIndex,
    EpisodeData data,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: data.images.toList().map((image) {
        return _buildImageTile(context, episodeIndex, image);
      }).toList(),
    ).paddingOnly(bottom: 10);
  }

  Widget _buildImageTile(
    BuildContext context,
    int episodeIndex,
    SavedImage image,
  ) {
    return Stack(
      children: [
        SizedBox(
          width: 100,
          height: 140,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: DionImage(
              imageUrl: image.url,
              httpHeaders: image.headers,
              boxFit: BoxFit.cover,
              hasPopup: true,
              errorWidget: ColoredBox(
                color: context.theme.colorScheme.surfaceContainerHighest,
                child: const Center(
                  child: Icon(Icons.broken_image, size: 28),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: () => _deleteImage(episodeIndex, image),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

bool entryHasSavedContent(EntrySaved entry) {
  for (final data in entry.episodedata) {
    if (data.quotes.isNotEmpty || data.images.isNotEmpty) {
      return true;
    }
  }
  return false;
}
