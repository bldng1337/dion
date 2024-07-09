import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dionysos/data/Entry.dart';
import 'package:dionysos/data/activity.dart';
import 'package:dionysos/util/file_utils.dart';
import 'package:dionysos/util/utils.dart';
import 'package:dionysos/views/loadingscreenview.dart';
import 'package:dionysos/views/settingsview.dart';
import 'package:dionysos/views/watch/epubreaderview.dart';
import 'package:dionysos/views/watch/imglistreaderview.dart';
import 'package:dionysos/views/watch/paragraphreaderview.dart';
import 'package:dionysos/views/watch/pdfreaderview.dart';
import 'package:dionysos/views/watch/videoplayerview.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:language_code/language_code.dart';

Future<Widget?> _nav(Future<Source?> src) async {
  return (await src)?.navReader();
}

void navSource(BuildContext context, Future<Source?> src) {
  context.push('/any', extra: LoadingScreen(_nav(src)));
}

void navreplaceSource(BuildContext context, Future<Source?> src) {
  context.pushReplacement('/any', extra: LoadingScreen(_nav(src)));
}

enum SourceType {
  //todo: support "magnet"|"torrent"|
  directlink,
  data,
}

class SourceMeta {
  SourceMeta(this.name, this.files, this.data);
  
  final String name;
  final List<SourceFile> files;
  final Map<String, dynamic> data;
}

class SourceFile {
  SourceFile({this.data, this.url, required this.filename});

  bool get isdata {
    return data != null;
  }

  final Uint8List? data;
  final String? url;
  final String filename;
}

abstract class Source {
  Source(this.entry, this.ep) {
    //TODO: Rework this mess
    final List<int> epmap = entry.episodes
        .map((e) => e.episodes.indexWhere((p0) => p0.url == ep.url))
        .toList();
    eplist = entry.episodes[epmap.indexWhere((element) => element >= 0)];
    epcount = epmap.where((element) => element != -1).first;
  }
  
  factory Source.fromJson(
      Map<String, dynamic> json, EntryDetail entry, Episode e,) {
    switch (json['sourcetype']) {
      case 'data':
        switch(json['sourcedata']['type']) {
          case 'paragraphlist':
            return ParagraphListSource.fromJSON(json, entry, e);
          default:
            throw UnsupportedError('Not implemented ${json['sourcedata']['type']}');
        }
      case 'directlink':
        switch (json['sourcedata']['type']) {
          case 'm3u8':
            return M3U8Source.fromJSON(json, entry, e);
          case 'epub':
            return EpubSource.fromJSON(json, entry, e);
          case 'pdf':
            return PdfSource.fromJSON(json, entry, e);
          case 'imagelist':
            return ImgListSource.fromJSON(json, entry, e);
          default:
            throw UnsupportedError('Not implemented ${json['sourcedata']['type']}');
        }
    }
    throw UnsupportedError('Not implemented ${json['sourcetype']}');
  }
  
  final EntryDetail entry;
  final Episode ep;
  late final int epcount;
  late final AEpisodeList eplist;

  //Source lookup by List
  int getIndex() {
    return epcount;
  }

  int getLength() {
    return eplist.episodes.length;
  }

  Future<Source?> getByIndex(int index) async {
    if (index == getIndex()) {
      return this;
    }
    if(entry.ext==null){
      return null;
    }
    return entry.ext!.source(eplist.episodes[index], entry);
  }

  //Source Lookup by Jumps
  bool hasPrevious() {
    return getIndex() > 0;
  }

  Future<Source?> getPrevious() async {
    return getByIndex(getIndex() - 1);
  }

  bool hasNext() {
    return getLength() > getIndex() + 1;
  }

  Future<Source?> getNext() async {
    return getByIndex(getIndex() + 1);
  }

  String getSourceType() => runtimeType.toString().toLowerCase();

  EpisodeData getEpdata() {
    if (entry is EntrySaved) {
      return (entry as EntrySaved).getEpdata(epcount);
    }
    return EpisodeData();
  }

  Widget navReader() {
    if (entry is EntrySaved) {
      makeconsumeActivity(entry as EntrySaved, [getIndex()], ReadType.started);
    }
    return _navReader();
  }

  Widget _navReader();

  static Future<Source?> resolve(
      EntrySaved saved, AEpisodeList list, int episode,) async {
    if (list.getEpisode(episode) == null) {
      return null;
    }
    final Directory d = await saved.getDir(list, episode);
    final meta = json.decode(await d.getFile('meta.json').readAsString())
        as Map<String, dynamic>;
    switch (meta['name']) {
      case 'localparagraphlist':
        return ParagraphListSource(await d.getFile('data.txt').readAsLines(),
            saved, list.getEpisode(episode)!,);
      case 'localpdf':
        return PdfSource(
            d.getFile('src.pdf').path, saved, list.getEpisode(episode)!,
            local: true,);
      case 'localimglist':
        return ImgListSource(
            List.generate((meta['length'] as num).toInt(),
                (a) => d.getFile('$a.jpg').path,),
            null,
            saved,
            list.getEpisode(episode)!,
            local: true,);
      case 'localepub':
        return EpubSource(
            d.getFile('data.epub').path, saved, list.getEpisode(episode)!,
            local: true,);
    }
    return null;
  }

  Future<void> save() async {}

  SourceMeta getdownload();
}

class ImgListSource extends Source {
  final List<String> urls;
  final Map<String, String>? header;
  bool local;

  ImgListSource(this.urls,this.header, super.entry, super.ep,  {this.local = false});

  factory ImgListSource.fromJSON(
          Map<String, dynamic> json, EntryDetail entry, Episode e,) =>
      ImgListSource(
          listcast<String>(json['sourcedata']['links'] as List<dynamic>),
          (json['sourcedata']['header'] as Map<String, dynamic>?)?.cast<String, String>(),
          entry,
          e,);

  @override
  Widget _navReader() {
    return PaginatedImgListViewer(this, local: local);
  }

  @override
  SourceMeta getdownload() {
    return SourceMeta(
        'localimglist',
        urls.indexed
            .map((e) => SourceFile(filename: '${e.$1}.jpg', url: e.$2))
            .toList(),
        {'length': urls.length},);
  }
}

class M3U8Source extends Source {
  M3U8Source(this.url, this.sub, super.entry, super.ep);

  factory M3U8Source.fromJSON(
          Map<String, dynamic> json, EntryDetail entry, Episode e,) =>
      M3U8Source(
        json['sourcedata']['link'] as String,
        (json['sourcedata']['sub'] as List<dynamic>?)
                ?.asMap()
                .map((key, value) => MapEntry(
                    stringtoLang(value['title'].toString()),
                    value['url'].toString(),),)
                .where((p0, p1) => p0 != null)
                .map((key, value) =>
                    MapEntry(key! as LanguageCodes, value! as String),) ??
            {},
        entry,
        e,
      );

  final String url;
  final Map<LanguageCodes, String> sub;

  @override
  Widget _navReader() {
    return Videoplayer(this);
  }

  @override
  SourceMeta getdownload() {
    return SourceMeta('localm3u8', [
      SourceFile(filename: 'vid.m3u8', url: url),
      ...sub.entries.map((e) =>
          SourceFile(filename: '${e.key.nativeName}.sub.txt', url: e.value),),
    ], {
      'subtitles': sub.keys.map((e) => '${e.nativeName}.sub.txt').toList(),
    });
  }
}

class PdfSource extends Source {
  final String url;
  final bool local;

  PdfSource(this.url, super.entry, super.ep, {this.local = false});

  @override
  Widget _navReader() {
    return Pdfreader(this, local: local);
  }

  factory PdfSource.fromJSON(
          Map<String, dynamic> json, EntryDetail entry, Episode e,) =>
      PdfSource(json['sourcedata']['link'] as String, entry, e);

  @override
  SourceMeta getdownload() {
    return SourceMeta(
        'localpdf', [SourceFile(filename: 'src.pdf', url: url)], {},);
  }
}

class EpubSource extends Source {
  final String url;
  final bool local;
  EpubSource(this.url, super.entry, super.ep, {this.local = false});

  @override
  Widget _navReader() {
    return Epubreader(this, local: local);
  }

  factory EpubSource.fromJSON(
          Map<String, dynamic> json, EntryDetail entry, Episode e,) =>
      EpubSource(json['sourcedata']['link'] as String, entry, e);

  @override
  SourceMeta getdownload() {
    return SourceMeta(
        'localepub', [SourceFile(filename: 'data.epub', url: url)], {},);
  }
}

class ParagraphListSource extends Source {
  final List<String> paragraphs;
  ParagraphListSource(this.paragraphs, super.entry, super.ep);

  @override
  Widget _navReader() {
    if(TextReaderSettings.reader.value == 'Infinityscroll'){
      return InfinityParagraphreader(source: this,);
    }
    return ParagraphReader(
      source: this,
    );
  }

  factory ParagraphListSource.fromJSON(
          Map<String, dynamic> json, EntryDetail entry, Episode e,) =>
      ParagraphListSource(
          listcast<String>(json['sourcedata']['paragraphs'] as List<dynamic>),
          entry,
          e,);

  @override
  SourceMeta getdownload() {
    return SourceMeta('localparagraphlist', [
      SourceFile(
          filename: 'data.txt', data: stringtoutf8(paragraphs.join('\n')),),
    ], {},);
  }
}
