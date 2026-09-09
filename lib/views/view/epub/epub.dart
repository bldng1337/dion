import 'package:dionysos/views/view/epub/simple_reader.dart';
import 'package:dionysos/views/view/view.dart';
import 'package:dionysos/views/view/wrapper.dart';
import 'package:flutter/cupertino.dart';

class EpubReader extends StatelessWidget {
  const EpubReader({super.key});

  @override
  Widget build(BuildContext context) {
    return SourceWrapper(
      builder: (context, source) => SimpleEpubReader(
        // Keyed by source so switching episodes loads a fresh book with its
        // own saved CFI instead of reusing the previous reader state.
        key: ValueKey(source.source),
        source: source,
        supplier: SourceSuplierData.of(context)!.supplier,
      ),
      source: SourceSuplierData.of(context)!.supplier,
    );
  }
}
