import 'package:awesome_extensions/awesome_extensions.dart';
import 'package:flutter/material.dart';

class Foldabletext extends StatefulWidget {
  final String text;
  final int maxLines;
  final TextStyle? style;
  final TextAlign? textAlign;
  final bool animate;
  const Foldabletext(
    this.text, {
    super.key,
    this.maxLines = 3,
    this.style,
    this.textAlign,
    this.animate = true,
  });

  @override
  _FoldabletextState createState() => _FoldabletextState();
}

Size getTextSize(
  String text,
  TextStyle? style, {
  double? width,
  TextAlign? textAlign,
}) {
  final TextPainter textPainter = TextPainter(
    text: TextSpan(text: text, style: style),
    textAlign: textAlign ?? TextAlign.start,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: width ?? double.infinity);
  return textPainter.size;
}

class _FoldabletextState extends State<Foldabletext> {
  bool _isExpanded = false;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (getTextSize(
              widget.text,
              widget.style,
              width: constraints.maxWidth,
            ).height >
            (widget.style?.fontSize ?? 14.0) * (widget.maxLines + 1)) {
          if (!widget.animate) {
            return StatefulBuilder(
              builder: (context, setState) =>
                  (!_isExpanded
                          ? Column(
                              children: [
                                Text(
                                  widget.text,
                                  maxLines: widget.maxLines,
                                  overflow: TextOverflow.ellipsis,
                                  style: widget.style,
                                  textAlign: widget.textAlign,
                                ),
                                const Icon(Icons.keyboard_arrow_down),
                              ],
                            )
                          : Text(
                              widget.text,
                              style: widget.style,
                              textAlign: widget.textAlign,
                            ))
                      .onTap(
                        () => setState(() {
                          _isExpanded = !_isExpanded;
                        }),
                      ),
            );
          }
          return StatefulBuilder(
            builder: (context, setState) =>
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 200),
                  crossFadeState: _isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: Column(
                    children: [
                      Text(
                        widget.text,
                        maxLines: widget.maxLines,
                        overflow: TextOverflow.ellipsis,
                        style: widget.style,
                        textAlign: widget.textAlign,
                      ),
                      const Icon(Icons.keyboard_arrow_down),
                    ],
                  ),
                  secondChild: Text(
                    widget.text,
                    style: widget.style,
                    textAlign: widget.textAlign,
                  ),
                ).onTap(
                  () => setState(() {
                    _isExpanded = !_isExpanded;
                  }),
                ),
          );
        }
        return Text(
          widget.text,
          style: widget.style,
          textAlign: widget.textAlign,
        );
      },
    );
  }
}
