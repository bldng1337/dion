import 'package:dionysos/data/source.dart';
import 'package:dionysos/views/view/audio/simple_listener.dart';
import 'package:flutter/cupertino.dart';

class AudioListener extends StatelessWidget {
  final SourceSupplier supplier;

  const AudioListener({super.key, required this.supplier});

  @override
  Widget build(BuildContext context) {
    return SimpleAudioListener(source: supplier);
  }
}
