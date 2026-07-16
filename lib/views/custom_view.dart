import 'package:dionysos/service/extension.dart';
import 'package:dionysos/views/customui.dart';
import 'package:dionysos/widgets/scaffold.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

class CustomUIViewData {
  final String? title;
  final CustomUI ui;
  final Extension extension;
  CustomUIViewData({this.title, required this.ui, required this.extension});
}

class CustomUiView extends StatelessWidget {
  /// The data to render. When null (e.g. when reached via the `/custom` router
  /// route) it is read from the current [GoRouterState].
  final CustomUIViewData? data;

  const CustomUiView({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    final d = data ??
        (GoRouterState.of(context).extra! as List<Object?>)[0]!
            as CustomUIViewData;
    return NavScaff(
      title: d.title != null ? Text(d.title!) : null,
      child: CustomUIWidget.fromUI(ui: d.ui, extension: d.extension),
    );
  }
}
