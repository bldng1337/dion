import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dionysos/Source.dart';
import 'package:epub_view/epub_view.dart';
import 'package:flutter/material.dart';
import 'package:internet_file/internet_file.dart';

class Epubreader extends StatefulWidget {
  
  final EpubSource source;
  final bool local;
  const Epubreader(this.source,{ super.key, this.local=false });

  @override
  createState() => _EpubreaderState();
}

class _EpubreaderState extends State<Epubreader> {
  late EpubController _epubController;
  Timer? timer;
  double progress=0;
  bool downloading=true;
  Future<Uint8List> getData(){
    if(widget.local){
      File f = File(widget.source.url);
      return f.readAsBytes();
    }
    return InternetFile.get(widget.source.url,progress: (receivedLength, contentLength) => setState(() {
    progress=(receivedLength.toDouble()/contentLength);
  }),);
  }

  Future<EpubBook> getEpub() async {
  Uint8List data=await getData();
  setState(() {
    downloading=false;
  });
  return EpubDocument.openData(data);
}

void save(){
  final cfi = _epubController.generateEpubCfi();
  widget.source.getEpdata().sprogress=cfi;
  widget.source.entry.save();
}

@override
  void dispose() {
    timer?.cancel();
    save();
    _epubController.dispose();
    super.dispose();
  }

@override
void initState() {
  super.initState();
  timer = Timer.periodic(const Duration(seconds: 15), (timer) => save());
  _epubController = EpubController(
    document: getEpub(),
    epubCfi: widget.source.getEpdata().sprogress??"",
  );
  
}

@override
Widget build(BuildContext context) {
  if(downloading){
    return Scaffold(
      appBar: AppBar(),
      body: Center(child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
      const Text("Loading"),
      CircularProgressIndicator(value: progress,)
    ],),),);
  }
  return Scaffold(
  appBar: AppBar(
    title: EpubViewActualChapter(
      controller: _epubController,
      builder: (chapterValue) => Text(
        'Chapter: ${chapterValue?.chapter?.Title?.replaceAll('\n', '').trim() ?? ''}',
        textAlign: TextAlign.start,
      )
    ),
  ),
  // drawer: Drawer(
  //   child: EpubViewTableOfContents(
  //     controller: _epubController,
  //   ),
  // ),
  body: EpubView(
    controller: _epubController,
  ),
);}
}