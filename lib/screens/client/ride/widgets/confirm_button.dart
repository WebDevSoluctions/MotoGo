import 'package:flutter/material.dart';

import '../../../../config/colors.dart';

class ConfirmButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool loading;
  final String text;

  const ConfirmButton({
    super.key,
    required this.onPressed,
    this.loading = false,
    this.text = 'Confirmar corrida',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,

      child: ElevatedButton(
        onPressed:
            loading ? null : onPressed,

        style: ElevatedButton.styleFrom(
          backgroundColor:
              AppColors.primary,

          foregroundColor:
              Colors.white,

          disabledBackgroundColor:
              Colors.grey.shade300,

          disabledForegroundColor:
              Colors.grey.shade600,

          elevation: 3,

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(16),
          ),
        ),

        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,

                child:
                    CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,

                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 23,
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  Text(
                    text,

                    style:
                        const TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}