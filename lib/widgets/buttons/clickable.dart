import 'package:dionysos/utils/theme.dart';
import 'package:flutter/material.dart';

class Clickable extends StatefulWidget {
  final Widget child;
  final Function()? onTap;
  final Function()? onLongTap;
  const Clickable({super.key, required this.child, this.onTap, this.onLongTap});

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
      child: InkWell(
        borderRadius: BorderRadius.circular(3),
        onTap: widget.onTap,
        onLongPress: widget.onLongTap,
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
                      ? Colors.white.withValues(alpha: 0.03)
                      : Colors.black.withValues(alpha: 0.03),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
