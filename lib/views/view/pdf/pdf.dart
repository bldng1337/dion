import 'package:dionysos/views/view/pdf/simple_reader.dart';
import 'package:dionysos/views/view/view.dart';
import 'package:dionysos/views/view/wrapper.dart';
import 'package:flutter/cupertino.dart';

class PdfReader extends StatelessWidget {
  const PdfReader({super.key});

  @override
  Widget build(BuildContext context) {
    return SourceWrapper(
      builder: (context, source) => SimplePdfReader(
        // Keyed by source so switching episodes loads a fresh document with
        // its own saved progress instead of reusing the previous viewer state.
        key: ValueKey(source.source),
        source: source,
        supplier: SourceSuplierData.of(context)!.supplier,
      ),
      source: SourceSuplierData.of(context)!.supplier,
    );
  }
}
