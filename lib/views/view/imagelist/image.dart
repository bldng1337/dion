import 'package:dionysos/data/source.dart';
import 'package:dionysos/views/view/imagelist/simple_reader.dart';
import 'package:dionysos/views/view/wrapper.dart';
import 'package:flutter/cupertino.dart';

class ImageListReader extends StatelessWidget {
  final SourceSupplier supplier;

  const ImageListReader({super.key, required this.supplier});

  @override
  Widget build(BuildContext context) {
    return SourceWrapper(
      builder: (context, source) =>
          SimpleImageListReader(source: source, supplier: supplier),
      source: supplier,
    );
  }
}
