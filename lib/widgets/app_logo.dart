import 'package:flutter/material.dart';

import '../config/colors.dart';

class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({
    super.key,
    this.size = 110,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,

      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(28),
      ),

      child: Icon(
        Icons.two_wheeler_rounded,
        color: Colors.white,
        size: size * .55,
      ),
    );
  }
}