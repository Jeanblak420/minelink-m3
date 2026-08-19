import 'package:flutter/material.dart';

/// A simple loading indicator widget
class LoadingIndicator extends StatelessWidget {
  final double size;
  final Color? color;

  const LoadingIndicator({super.key, this.size = 24.0, this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: 3.0,
          valueColor: color != null
              ? AlwaysStoppedAnimation<Color>(color!)
              : null,
        ),
      ),
    );
  }
}
