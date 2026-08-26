import 'package:flutter/material.dart';

import '../../../../config/colors.dart';

class RideTypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String value;
  final String selectedValue;
  final ValueChanged<String> onChanged;

  const RideTypeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.selectedValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool selected =
        value == selectedValue;

    return InkWell(
      onTap: () {
        onChanged(value);
      },

      borderRadius:
          BorderRadius.circular(18),

      child: AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 200,
        ),

        width: double.infinity,

        padding:
            const EdgeInsets.all(16),

        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
                  .withOpacity(0.08)
              : Colors.white,

          borderRadius:
              BorderRadius.circular(18),

          border: Border.all(
            color: selected
                ? AppColors.primary
                : Colors.grey
                    .withOpacity(0.15),

            width:
                selected ? 2 : 1,
          ),

          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withOpacity(
                0.04,
              ),

              blurRadius: 10,

              offset:
                  const Offset(0, 4),
            ),
          ],
        ),

        child: Row(
          children: [

            // ==================================================
            // ÍCONE
            // ==================================================

            Container(
              width: 52,
              height: 52,

              decoration:
                  BoxDecoration(
                color: selected
                    ? AppColors.primary
                        .withOpacity(0.12)
                    : Colors.grey
                        .withOpacity(0.08),

                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
              ),

              child: Icon(
                icon,

                size: 28,

                color: selected
                    ? AppColors.primary
                    : Colors.grey.shade700,
              ),
            ),

            const SizedBox(
              width: 15,
            ),

            // ==================================================
            // INFORMAÇÕES
            // ==================================================

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  Text(
                    title,

                    style:
                        const TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 4,
                  ),

                  Text(
                    subtitle,

                    style:
                        const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // SELEÇÃO
            // ==================================================

            Icon(
              selected
                  ? Icons
                      .radio_button_checked
                  : Icons
                      .radio_button_off,

              color: selected
                  ? AppColors.primary
                  : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}