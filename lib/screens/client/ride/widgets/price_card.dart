import 'package:flutter/material.dart';

import '../../../../config/colors.dart';

class PriceCard extends StatelessWidget {
  final double price;

  const PriceCard({
    super.key,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Row(
        children: [
          // ======================================================
          // ÍCONE
          // ======================================================

          Container(
            width: 50,
            height: 50,

            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),

            child: Icon(
              Icons.payments_outlined,
              color: AppColors.primary,
              size: 27,
            ),
          ),

          const SizedBox(width: 15),

          // ======================================================
          // DESCRIÇÃO
          // ======================================================

          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimativa da corrida',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),

                SizedBox(height: 4),

                Text(
                  'Valor aproximado',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          // ======================================================
          // PREÇO
          // ======================================================

          Text(
            'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}