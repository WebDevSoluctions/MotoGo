import 'package:flutter/material.dart';

import '../../../../config/colors.dart';

class DestinationCard extends StatelessWidget {
  final TextEditingController controller;

  const DestinationCard({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),

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
            'Destino',

            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          // ======================================================
          // CAMPO DE DESTINO
          // ======================================================

          TextField(
            controller: controller,

            textInputAction:
                TextInputAction.done,

            decoration: InputDecoration(
              hintText:
                  'Para onde você vai?',

              prefixIcon: Icon(
                Icons.location_on_rounded,
                color:
                    AppColors.primary,
              ),

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