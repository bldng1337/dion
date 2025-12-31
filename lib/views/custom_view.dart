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
  const CustomUiView();

  @override
  Widget build(BuildContext context) {
    final data =
        (GoRouterState.of(context).extra! as List<Object?>)[0]!
            as CustomUIViewData;
    return NavScaff(
      title: data.title != null ? Text(data.title!) : null,
      child: CustomUIWidget.fromUI(ui: data.ui, extension: data.extension),
    );
  }
}
