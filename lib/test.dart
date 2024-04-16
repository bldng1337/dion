// import 'dart:async';

// import 'package:dionysos/widgets/hugelist.dart';
// import 'package:flutter/material.dart';
// import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';


// void main(){
//   return runApp(const MaterialApp(
//     home: Test(),
//   ));
// }



// class Test extends StatefulWidget {
//   const Test({ super.key });

//   @override
//   _TestState createState() => _TestState();
// }

// class _TestState extends State<Test> {
  
//   ScrollOffsetController sc=ScrollOffsetController();
//   Timer? t;
//   @override
//   void initState() {
//     t=Timer.periodic(const Duration(seconds: 1),(t) {
//       print("event");
//       sc.animateScroll(offset: 200, duration: const Duration(milliseconds: 200));
//     });
//     super.initState();
//   }
//   @override
//   Widget build(BuildContext context) {
//     return Hugelist<String>(
//       startMajor: 50,
//       scrollOffsetController: sc,
//       onscroll: (major,minor) {
//         print("Major $major Minor $minor");
//       },
//       builder: (
//       BuildContext context, int major, int minor, dynamic thing) { 
//         print("Render $major $minor");
//         return Container(
//           height: MediaQuery.of(context).size.height/2,
//           child: Text(thing),
//         ) as Widget;
//        }, 
//       load: (int major) { 
//         return List.generate(10, (index) => "Minor: $index Major: $major");
//       },

      
//     );
//   }
// }