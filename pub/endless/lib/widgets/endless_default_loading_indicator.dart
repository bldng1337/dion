import 'package:flutter/material.dart';

class EndlessDefaultLoadingIndicator extends StatelessWidget {
  const EndlessDefaultLoadingIndicator({key}) : super(key: key);

  @override
  build(context) {
    return Container(
      width: double.infinity,
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: const SizedBox(
        height: 30,
        width: 30,
        child: CircularProgressIndicator(
          strokeWidth: 4.0,
        ),
      ),
    );
  }
}
