import 'dart:math';

import 'package:dionysos/utils/log.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class BoundsWidget extends StatelessWidget {
  final Widget child;
  final Color color;
  final bool showChildren;

  const BoundsWidget({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.showChildren = false,
  });

  @override
  Widget build(BuildContext context) {
    return _RecursiveBoundsRender(
      color: color,
      showChildren: showChildren,
      child: child,
    );
  }
}

class _RecursiveBoundsRender extends SingleChildRenderObjectWidget {
  final Color color;
  final bool showChildren;

  const _RecursiveBoundsRender({
    required Widget child,
    required this.color,
    required this.showChildren,
  }) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RecursiveBoundsRenderObject(
      color: color,
      showChildren: showChildren,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RecursiveBoundsRenderObject renderObject,
  ) {
    renderObject
      ..color = color
      ..showChildren = showChildren;
  }
}

class _RecursiveBoundsRenderObject extends RenderProxyBox {
  Color color;
  bool showChildren;

  _RecursiveBoundsRenderObject({
    required this.color,
    required this.showChildren,
  });

  static final Set<Type> _layoutOnlyTypes = {
    RenderFlex,  // Rows and Columns
    RenderPositionedBox,  // Center widget
    RenderPadding,  // Padding widget
    RenderConstrainedBox,  // SizedBox and similar
    RenderCustomMultiChildLayoutBox,  // Custom layout widgets
    RenderStack,  // Stack widget
    RenderIndexedStack,  // IndexedStack widget
    RenderShrinkWrappingViewport,  // ListView and similar
    RenderViewport,  // ScrollView and similar
    RenderSliver,  // Sliver widgets
    RenderSliverList,  // SliverList
    RenderSliverGrid,  // SliverGrid
    RenderSliverPadding,  // SliverPadding
    RenderIgnorePointer,  // IgnorePointer widget
    RenderAbsorbPointer,  // AbsorbPointer widget
  };

  @override
  void paint(PaintingContext context, Offset offset) {
    if (showChildren) {
      super.paint(context, offset);
    }
    _paintBounds(context.canvas, offset);
  }

  void _paintBounds(Canvas canvas, Offset offset) {
    void visitChildren(RenderObject? object, Offset currentOffset) {
      object?.visitChildren((child) {
        if (child is RenderBox) {
          Offset childOffset = currentOffset;

          // Handle different types of ParentData
          final ParentData? parentData = child.parentData;
          if (parentData is BoxParentData) {
            childOffset += parentData.offset;
          }
          if (!_layoutOnlyTypes.contains(child.runtimeType)) {
            // logger.i(child.runtimeType);
            final bounds = child.paintBounds.shift(childOffset);
            final fillPaint = Paint()
              ..color = color
              ..style = PaintingStyle.fill;
            final radius =
                Radius.circular(min(min(bounds.width, bounds.height) / 5, 20));
            canvas.drawRRect(
              RRect.fromRectAndCorners(bounds,
                  bottomLeft: radius,
                  bottomRight: radius,
                  topLeft: radius,
                  topRight: radius),
              fillPaint,
            );
          }
          visitChildren(child, childOffset);
        }
      });
    }

    // Visit all children
    visitChildren(this, offset);
  }
}
