import 'dart:io';

import 'package:dionysos/Source.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:internet_file/internet_file.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';

class Pdfreader extends StatefulWidget {
  final PdfSource source;
  final bool local;
  const Pdfreader(this.source, {super.key, this.local = false});

  @override
  _PdfreaderState createState() => _PdfreaderState();
}

class _PdfreaderState extends State<Pdfreader> {
  late final PdfController pdfController;
  double downloadprogress = 0;
  bool downloading = true;

  Future<Uint8List> setfinshed(Future<Uint8List> data) async {
    final Uint8List ret = await data;
    if (mounted) {
      setState(() {
        downloading = false;
      });
    }
    return ret;
  }

  @override
  void dispose() {
    pdfController.dispose();
    downloading = false;
    super.dispose();
  }

  @override
  void initState() {
    if (widget.local || widget.source.url.startsWith('file:')) {
      final File f = switch (widget.source.url.startsWith('file:')) {
        true => File(widget.source.url.substring(7)),
        false => File(widget.source.url),
      };
      pdfController = PdfController(
        initialPage: widget.source.getEpdata().iprogress ?? 1,
        document: PdfDocument.openData(
          setfinshed(f.readAsBytes()),
        ),
      );
    } else {
      pdfController = PdfController(
        initialPage: widget.source.getEpdata().iprogress ?? 1,
        document: PdfDocument.openData(
          setfinshed(
            InternetFile.get(
              widget.source.url,
              progress: (receivedLength, contentLength) {
                if (downloading) {
                  setState(() {
                    downloadprogress = receivedLength / contentLength;
                  });
                }
              },
            ),
          ),
        ),
      );
    }

    super.initState();
  }

  void openwebview() {
    launchUrl(Uri.parse(widget.source.ep.weburl));
  }

  void bookmark() {
    setState(() {
      widget.source.getEpdata().isBookmarked =
          !widget.source.getEpdata().isBookmarked;
    });
  }

  void scrollUp() {
    pdfController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void scrollDown() {
    pdfController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void navPreviousChapter() {
    if (!widget.source.hasPrevious()) {
      return;
    }
    // widget.source.getPrevious().then(
    //     (value) => context.pushReplacement("/any", extra: value?.navReader()));
    navreplaceSource(context, widget.source.getPrevious());
  }

  void navNextChapter() {
    if (!widget.source.hasNext()) {
      return;
    }
    // widget.source.getNext().then(
    //     (value) => context.pushReplacement("/any", extra: value?.navReader()));
    // widget.source.entry.complete(widget.source.getIndex());
    navreplaceSource(context, widget.source.getNext());
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowUp): scrollUp,
          const SingleActivator(LogicalKeyboardKey.arrowDown): scrollDown,
          const SingleActivator(LogicalKeyboardKey.keyW): scrollUp,
          const SingleActivator(LogicalKeyboardKey.keyS): scrollDown,
          const SingleActivator(LogicalKeyboardKey.keyE): bookmark,
          const SingleActivator(LogicalKeyboardKey.keyQ): openwebview,
          const SingleActivator(LogicalKeyboardKey.keyD): navNextChapter,
          const SingleActivator(LogicalKeyboardKey.keyA): navPreviousChapter,
        },
        child: Scaffold(
          appBar: AppBar(
            // Show actual chapter name
            actions: [
              IconButton(
                autofocus: true,
                onPressed: openwebview,
                icon: const Icon(Icons.web_outlined),
              ),
              IconButton(
                icon: Icon(
                  widget.source.getEpdata().isBookmarked
                      ? Icons.bookmark
                      : Icons.bookmark_outline,
                ),
                onPressed: bookmark,
              ),
              IconButton(
                onPressed:
                    () {}, //enav(context, parreadsettings(update: ()=>setState((){})))
                icon: const Icon(Icons.settings),
              ),
            ],
          ),
          body: downloading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Loading Data'),
                      CircularProgressIndicator(
                        value: downloadprogress,
                      ),
                    ],
                  ),
                )
              : body(context),
        ),
      );

  Widget body(BuildContext context) => PdfView(
        pageSnapping: false,
        onPageChanged: (page) {
          widget.source.getEpdata().iprogress = page;
          widget.source.entry.save();
        },
        physics: const ClampingScrollPhysics(),
        scrollDirection: Axis.vertical,
        builders: PdfViewBuilders<DefaultBuilderOptions>(
          options: const DefaultBuilderOptions(),
          documentLoaderBuilder: (_) =>
              const Center(child: CircularProgressIndicator()),
          pageLoaderBuilder: (_) =>
              const Center(child: CircularProgressIndicator()),
          pageBuilder: _pageBuilder,
        ),
        controller: pdfController,
      );

  PhotoViewGalleryPageOptions _pageBuilder(
    BuildContext context,
    Future<PdfPageImage> pageImage,
    int index,
    PdfDocument document,
  ) {
    return PhotoViewGalleryPageOptions(
      imageProvider: PdfPageImageProvider(
        pageImage,
        index,
        document.id,
      ),
      tightMode: true,
      disableGestures: true,
      minScale: PhotoViewComputedScale.contained * 1,
      maxScale: PhotoViewComputedScale.contained * 2,
      initialScale: PhotoViewComputedScale.contained * 1.0,
      heroAttributes: PhotoViewHeroAttributes(tag: '${document.id}-$index'),
    );
  }
}
