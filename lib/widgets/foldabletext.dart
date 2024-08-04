import 'package:flutter/material.dart';

class Foldabletext extends StatefulWidget {
  final String text;
  final int maxLines;
  final TextStyle? style;
  final TextAlign? textAlign;
  const Foldabletext(this.text,{
    super.key,
    this.maxLines = 3,
    this.style,
    this.textAlign,
  });

  @override
  _FoldabletextState createState() => _FoldabletextState();
}

class _FoldabletextState extends State<Foldabletext> {
  bool _isExpanded = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: AnimatedCrossFade(
        duration: const Duration(milliseconds: 200),
        crossFadeState:
            _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        firstChild: Text(
          widget.text,
          maxLines: widget.maxLines,
          overflow: TextOverflow.ellipsis,
          style: widget.style,
          textAlign: widget.textAlign,
        ),
        secondChild: Text(
          widget.text,
          style: widget.style,
          textAlign: widget.textAlign,
        ),
      ),
    );
  }
}
