import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_js/quickjs/ffi.dart';
import 'package:intl/intl.dart';
import 'package:language_code/language_code.dart';
import 'package:share_plus/share_plus.dart';

extension FileUtils on Map {
  Map<K,V> where<K, V>(bool Function(K, V) test){
    Map<K,V> temp=Map.from(this);
    temp.removeWhere((a,b)=>!test(a,b));
    print(temp);
    return temp;
  }
}

bool isVertical(BuildContext ctx) {
  final s = MediaQuery.of(ctx).size;
  return s.width < s.height;
}

String formatNumber(int num) {
  final formatter = NumberFormat.compact(locale: "en_US", explicitSign: false);
  return formatter.format(num);
}

String getPlatform() {
  if (Platform.isIOS) {
    return "IOS";
  } else if (Platform.isAndroid) {
    return "ANDROID";
  } else if (Platform.isMacOS) {
    return "MACOS";
  } else if (Platform.isWindows) {
    return "WINDOWS";
  } else if (Platform.isFuchsia) {
    return "FUCHSIA";
  } else {
    return "UNKWON";
  }
}

void share(String s) async {
  if (getPlatform() == "WINDOWS") {
    await Clipboard.setData(ClipboardData(text: s));
  }
  Share.share(s);
}

class SwipeDetector extends StatelessWidget {
  static const double minMainDisplacement = 50;
  static const double maxCrossRatio = 0.75;
  static const double minVelocity = 300;

  final Widget child;

  final VoidCallback? onSwipeUp;
  final VoidCallback? onSwipeDown;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;

  const SwipeDetector({
    super.key,
    required this.child,
    this.onSwipeUp,
    this.onSwipeDown,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.onDoubleTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    DragStartDetails? panStartDetails;
    DragUpdateDetails? panUpdateDetails;

    return GestureDetector(
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      onTapDown: (_) => panUpdateDetails =
          null, // This prevents two fingers quick taps from being detected as a swipe
      behavior: HitTestBehavior
          .opaque, // This allows swipe above other clickable widgets
      child: child,
      onPanStart: (startDetails) => panStartDetails = startDetails,
      onPanUpdate: (updateDetails) => panUpdateDetails = updateDetails,
      onPanEnd: (endDetails) {
        if (panStartDetails == null || panUpdateDetails == null) return;

        double dx = panUpdateDetails!.globalPosition.dx -
            panStartDetails!.globalPosition.dx;
        double dy = panUpdateDetails!.globalPosition.dy -
            panStartDetails!.globalPosition.dy;

        int panDurationMiliseconds =
            panUpdateDetails!.sourceTimeStamp!.inMilliseconds -
                panStartDetails!.sourceTimeStamp!.inMilliseconds;

        double mainDis, crossDis, mainVel;
        bool isHorizontalMainAxis = dx.abs() > dy.abs();

        if (isHorizontalMainAxis) {
          mainDis = dx.abs();
          crossDis = dy.abs();
        } else {
          mainDis = dy.abs();
          crossDis = dx.abs();
        }

        mainVel = 1000 * mainDis / panDurationMiliseconds;

        // if (mainDis < minMainDisplacement) return;
        // if (crossDis > maxCrossRatio * mainDis) return;
        // if (mainVel < minVelocity) return;

        if (mainDis < minMainDisplacement) {
          debugPrint(
              "SWIPE DEBUG | Displacement too short. Real: $mainDis - Min: $minMainDisplacement");
          return;
        }
        if (crossDis > maxCrossRatio * mainDis) {
          debugPrint(
              "SWIPE DEBUG | Cross axis displacemnt bigger than limit. Real: $crossDis - Limit: ${mainDis * maxCrossRatio}");
          return;
        }
        if (mainVel < minVelocity) {
          debugPrint(
              "SWIPE DEBUG | Swipe velocity too slow. Real: $mainVel - Min: $minVelocity");
          return;
        }

        // dy < 0 => UP -- dx > 0 => RIGHT
        if (isHorizontalMainAxis) {
          if (dx > 0)
            onSwipeRight?.call();
          else
            onSwipeLeft?.call();
        } else {
          if (dy < 0)
            onSwipeUp?.call();
          else
            onSwipeDown?.call();
        }
      },
    );
  }
}

LanguageCodes? stringtoLang(String? ilang) {
  if(ilang==null){
    return null;
  }
  String lang=ilang.toLowerCase();
  
  return LanguageCodes.values.firstWhereOrNull((p0) =>
      lang==p0.code.toLowerCase() ||
      p0.englishNames.map((e) => lang.contains(e.toLowerCase())).contains(true) ||
      p0.nativeNames.map((e) => lang.contains(e.toLowerCase())).contains(true) ||
      lang==p0.locale.countryCode?.toLowerCase() ||
      lang==p0.locale.languageCode.toLowerCase()||
      lang==p0.locale.scriptCode?.toLowerCase());
}

List<T> listcast<T>(List<dynamic> list) => list.map((e) => e as T).toList();
List<T>? mlistcast<T>(List<dynamic>? list) => list?.map((e) => e as T).toList();
