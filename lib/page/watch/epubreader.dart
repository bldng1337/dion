import 'dart:async';
import 'dart:typed_data';

import 'package:dionysos/Source.dart';
import 'package:epub_view/epub_view.dart';
import 'package:flutter/material.dart';
import 'package:internet_file/internet_file.dart';

class Epubreader extends StatefulWidget {
  
  final EpubSource source;
  const Epubreader(this.source,{ super.key });

  @override
  _EpubreaderState createState() => _EpubreaderState();
}

class _EpubreaderState extends State<Epubreader> {
  late EpubController _epubController;
  Timer? timer;
  double progress=0;
  bool downloading=true;
  Future<EpubBook> getEpub() async {
  Uint8List data=await InternetFile.get(widget.source.url,progress: (receivedLength, contentLength) => setState(() {
    progress=(receivedLength.toDouble()/contentLength);
  }),);
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
    // Load document
    document: getEpub(),
    // Set start point
    epubCfi: widget.source.getEpdata().getSProgress(""),
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
    // Show actual chapter name
    title: EpubViewActualChapter(
      controller: _epubController,
      builder: (chapterValue) => Text(
        'Chapter: ${chapterValue?.chapter?.Title?.replaceAll('\n', '').trim() ?? ''}',
        textAlign: TextAlign.start,
      )
    ),
  ),
  // Show table of contents
  // drawer: Drawer(
  //   child: EpubViewTableOfContents(
  //     controller: _epubController,
  //   ),
  // ),
  // Show epub document
  body: EpubView(
    controller: _epubController,
  ),
);}
}