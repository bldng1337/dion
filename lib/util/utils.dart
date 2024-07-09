import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_js/quickjs/ffi.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:language_code/language_code.dart';
import 'package:share_plus/share_plus.dart';

extension MapUtils on Map {
  Map<K, V> where<K, V>(bool Function(K, V) test) {
    final Map<K, V> temp = Map.from(this);
    temp.removeWhere((a, b) => !test(a, b));
    return temp;
  }
}

bool isVertical(BuildContext ctx) {
  final s = MediaQuery.of(ctx).size;
  return s.width < s.height;
}

String formatNumber(int num) {
  final formatter = NumberFormat.compact(locale: 'en_US');
  return formatter.format(num);
}

enum CPlatform { ios, android, macos, windows, fuchsia, unknown }

CPlatform getPlatform() {
  if (Platform.isIOS) {
    return CPlatform.ios;
  } else if (Platform.isAndroid) {
    return CPlatform.android;
  } else if (Platform.isMacOS) {
    return CPlatform.macos;
  } else if (Platform.isWindows) {
    return CPlatform.windows;
  } else if (Platform.isFuchsia) {
    return CPlatform.fuchsia;
  } else {
    return CPlatform.unknown;
  }
}

Future<void> share(String s) async {
  if (getPlatform() == CPlatform.windows) {
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

        final double dx = panUpdateDetails!.globalPosition.dx -
            panStartDetails!.globalPosition.dx;
        final double dy = panUpdateDetails!.globalPosition.dy -
            panStartDetails!.globalPosition.dy;

        final int panDurationMiliseconds =
            panUpdateDetails!.sourceTimeStamp!.inMilliseconds -
                panStartDetails!.sourceTimeStamp!.inMilliseconds;

        double mainDis;
        double crossDis;
        double mainVel;
        final bool isHorizontalMainAxis = dx.abs() > dy.abs();

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
            'SWIPE DEBUG | Displacement too short. Real: $mainDis - Min: $minMainDisplacement',
          );
          return;
        }
        if (crossDis > maxCrossRatio * mainDis) {
          debugPrint(
            'SWIPE DEBUG | Cross axis displacemnt bigger than limit. Real: $crossDis - Limit: ${mainDis * maxCrossRatio}',
          );
          return;
        }
        if (mainVel < minVelocity) {
          debugPrint(
            'SWIPE DEBUG | Swipe velocity too slow. Real: $mainVel - Min: $minVelocity',
          );
          return;
        }

        // dy < 0 => UP -- dx > 0 => RIGHT
        if (isHorizontalMainAxis) {
          if (dx > 0) {
            onSwipeRight?.call();
          } else {
            onSwipeLeft?.call();
          }
        } else {
          if (dy < 0) {
            onSwipeUp?.call();
          } else {
            onSwipeDown?.call();
          }
        }
      },
    );
  }
}

LanguageCodes? stringtoLang(String? ilang) {
  if (ilang == null) {
    return null;
  }
  final String lang = ilang.toLowerCase();

  return LanguageCodes.values.firstWhereOrNull(
    (p0) =>
        lang == p0.code.toLowerCase() ||
        p0.englishNames
            .map((e) => lang.contains(e.toLowerCase()))
            .contains(true) ||
        p0.nativeNames
            .map((e) => lang.contains(e.toLowerCase()))
            .contains(true) ||
        lang == p0.locale.countryCode?.toLowerCase() ||
        lang == p0.locale.languageCode.toLowerCase() ||
        lang == p0.locale.scriptCode?.toLowerCase(),
  );
}

List<T> listcast<T>(List<dynamic> list) => list.map((e) => e as T).toList();
List<T>? mlistcast<T>(List<dynamic>? list) => list?.map((e) => e as T).toList();

class BareScaffold extends StatelessWidget {
  final Widget child;
  const BareScaffold(this.child, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: child,
    );
  }
}

class FutureLoader<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(BuildContext context, T data) success;
  final Widget Function(BuildContext context, Object error)? error;
  final Widget Function(BuildContext context)? loading;
  const FutureLoader(
    this.future, {
    super.key,
    required this.success,
    this.error,
    this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (error != null) {
            return error!(context, snapshot.error!);
          }
          return Container();
        }
        if (snapshot.hasData) {
          return success(context, snapshot.data as T);
        }
        if (loading != null) {
          return loading!(context);
        }
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }
}

void enav(BuildContext context, Widget w) {
  context.push('/any', extra: w);
}

class Any extends StatelessWidget {
  const Any({super.key});

  @override
  Widget build(BuildContext context) {
    return GoRouterState.of(context).extra! as Widget;
  }
}

class ConstructionWarning extends StatelessWidget {
  const ConstructionWarning({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        children: [
          Icon(
            Icons.construction,
            size: 150,
          ),
          Text(
            'Under Construction',
            style: TextStyle(fontSize: 30),
          ),
          Text(
            'This feature is not finished',
            style: TextStyle(fontSize: 15),
          ),
        ],
      ),
    );
  }
}

FontWeight stringToFontWeight(String weight) {
  switch (weight) {
    case 'Thin':
      return FontWeight.w100;
    case 'ExtraLight':
      return FontWeight.w200;
    case 'Light':
      return FontWeight.w300;
    case 'Normal':
      return FontWeight.w400;
    case 'Medium':
      return FontWeight.w500;
    case 'SemiBold':
      return FontWeight.w600;
    case 'Bold':
      return FontWeight.w700;
    case 'ExtraBold':
      return FontWeight.w800;
    case 'Black':
      return FontWeight.w900;
  }
  return FontWeight.w400;
}

String fontWeightToString(FontWeight weight) {
  switch (weight.index) {
    case 0:
      return 'Thin';
    case 1:
      return 'ExtraLight';
    case 2:
      return 'Light';
    case 3:
      return 'Normal';
    case 4:
      return 'Medium';
    case 5:
      return 'SemiBold';
    case 6:
      return 'Bold';
    case 7:
      return 'ExtraBold';
    case 8:
      return 'Black';
  }
  return 'Normal';
}

Widget displayJSON(dynamic jsonlike) {
  if (jsonlike is Map<String, dynamic>) {
    if (jsonlike.isEmpty) {
      return Container();
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: jsonlike.length,
      itemBuilder: (context, index) {
        return ListTile(
            title: Text(jsonlike.keys.elementAt(index)),
            subtitle: displayJSON(jsonlike.values.elementAt(index)));
      },
    );
  }
  if (jsonlike is List<dynamic>) {
    if (jsonlike.isEmpty) {
      return Container();
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: jsonlike.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(index.toString()),
          subtitle: displayJSON(jsonlike.elementAt(index)));
      },
    );
  }
  if(jsonlike is String){
    try {
      final dt=DateTime.parse(jsonlike);
      return Text(durationToRelativeTime(dt.difference(DateTime.now())));
    // ignore: empty_catches
    }catch(e){}//This is expected
  }
  return Text(jsonlike.toString());
}


String durationToRelativeTime(Duration duration) {
  final isago=duration.isNegative;
  final absduration = duration.abs();
  String result = '';
  int value;

  if (absduration.inDays >= 365) {
    value = absduration.inDays ~/ 365;
    result = '$value year${value > 1 ? 's' : ''}';
  } else if (absduration.inDays >= 30) {
    value = absduration.inDays ~/ 30;
    result = '$value month${value > 1 ? 's' : ''}';
  } else if (absduration.inDays > 0) {
    value = absduration.inDays;
    result = '$value day${value > 1 ? 's' : ''}';
  } else if (absduration.inHours > 0) {
    value = absduration.inHours;
    result = '$value hour${value > 1 ? 's' : ''}';
  } else if (absduration.inMinutes > 0) {
    value = absduration.inMinutes;
    result = '$value minute${value > 1 ? 's' : ''}';
  } else {
    value = absduration.inSeconds;
    result = '$value second${value > 1 ? 's' : ''}';
  }

  return isago ? '$result ago' : 'in $result';
}
