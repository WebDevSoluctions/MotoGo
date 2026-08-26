import 'package:flutter/material.dart';

import '../../../../config/colors.dart';

class OriginCard extends StatelessWidget {
  final TextEditingController controller;

  final VoidCallback? onLocationPressed;

  const OriginCard({
    super.key,
    required this.controller,
    this.onLocationPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(18),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(0.05),

            blurRadius: 12,

            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          // ======================================================
          // TÍTULO
          // ======================================================

          const Text(
            'Local de partida',

            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          // ======================================================
          // CAMPO DE ORIGEM
          // ======================================================

          TextField(
            controller: controller,

            textInputAction:
                TextInputAction.next,

            decoration: InputDecoration(
              hintText:
                  'Onde você está?',

              prefixIcon: Icon(
                Icons.my_location_rounded,

                color:
                    AppColors.primary,
              ),

              suffixIcon:
                  onLocationPressed != null
                      ? IconButton(
                          onPressed:
                              onLocationPressed,

                          icon: Icon(
                            Icons
                                .gps_fixed_rounded,

                            color:
                                AppColors.primary,
                          ),
                        )
                      : null,

              filled: true,

              fillColor:
                  AppColors.background,

              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),

                borderSide:
                    BorderSide.none,
              ),

              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),

                borderSide:
                    BorderSide.none,
              ),

              focusedBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),

                borderSide: BorderSide(
                  color:
                      AppColors.primary,

                  width: 1.5,
                ),
              ),

              contentPadding:
                  const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}