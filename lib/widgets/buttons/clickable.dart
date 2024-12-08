import 'package:dionysos/utils/theme.dart';
import 'package:flutter/material.dart';

class Clickable extends StatefulWidget {
  final Widget child;
  final Function()? onTap;
  const Clickable({super.key, required this.child, this.onTap});

  @override
  State<Clickable> createState() => _ClickableState();
}

class _ClickableState extends State<Clickable> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (e) => setState(() => _hover = true),
      onExit: (e) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          children: [
            widget.child,
            if (_hover)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: DionTheme.of(context).brightness == Brightness.dark
                      ? Colors.black.withOpacity(0.07)
                      : Colors.white.withOpacity(0.07),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
