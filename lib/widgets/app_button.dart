import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {

  final String text;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool loading;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {

    return SizedBox(

      width: double.infinity,

      height: 55,

      child: ElevatedButton(

        onPressed: loading ? null : onPressed,

        child: loading

            ? const CircularProgressIndicator(
                color: Colors.white,
              )

            : Row(

                mainAxisAlignment: MainAxisAlignment.center,

                children: [

                  if (icon != null) ...[

                    Icon(icon),

                    const SizedBox(width: 10),

                  ],

                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                ],

              ),

      ),

    );

  }

}