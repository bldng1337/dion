import 'package:dionysos/views/view/audio/simple_listener.dart';
import 'package:dionysos/views/view/view.dart';
import 'package:flutter/cupertino.dart';

class AudioListener extends StatelessWidget {

  const AudioListener({super.key});

  @override
  Widget build(BuildContext context) {
    return SimpleAudioListener(source: SourceSuplierData.of(context)!.supplier);
  }
}
