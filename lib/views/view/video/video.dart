import 'package:dionysos/data/source.dart';
import 'package:dionysos/views/view/video/simple_video_player.dart';
import 'package:flutter/cupertino.dart';

class VideoPlayer extends StatelessWidget {
  final SourceSupplier supplier;

  const VideoPlayer({super.key, required this.supplier});

  @override
  Widget build(BuildContext context) {
    return SimpleVideoPlayer(source: supplier);
  }
}
