import 'package:dionysos/views/view/video/simple_video_player.dart';
import 'package:dionysos/views/view/view.dart';
import 'package:flutter/cupertino.dart';

class VideoPlayer extends StatelessWidget {
  const VideoPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return SimpleVideoPlayer(source: SourceSuplierData.of(context)!.supplier);
  }
}
