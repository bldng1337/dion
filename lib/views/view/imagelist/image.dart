import 'package:dionysos/views/view/imagelist/simple_reader.dart';
import 'package:dionysos/views/view/view.dart';
import 'package:dionysos/views/view/wrapper.dart';
import 'package:flutter/cupertino.dart';

class ImageListReader extends StatelessWidget {

  const ImageListReader({super.key});

  @override
  Widget build(BuildContext context) {
    return SourceWrapper(
      builder: (context, source) =>
          SimpleImageListReader(source: source, supplier: SourceSuplierData.of(context)!.supplier),
      source: SourceSuplierData.of(context)!.supplier,
    );
  }
}
