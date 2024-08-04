import 'package:flutter/material.dart';

class Delayedbuild extends StatelessWidget {
  final Duration? duration;
  final Widget Function() child; 
  final Widget Function()? loading;
  const Delayedbuild({this.duration, super.key,required this.child,this.loading});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.delayed(duration??const Duration(milliseconds: 100)),
      builder: (context, snapshot) {
        if (snapshot.connectionState!=ConnectionState.done) {
          if(loading!=null){
            return loading!();
          }
          return const CircularProgressIndicator();
        }
        return child();
      },
    );
  }
}
