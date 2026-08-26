import 'package:flutter/material.dart';

import '../../../config/colors.dart';

class PriceCard extends StatelessWidget {
  final double price;
  final double? distanceKm;
  final String title;

  const PriceCard({
    super.key,
    required this.price,
    this.distanceKm,
    this.title = 'Valor estimado',
  });

  String get formattedPrice {
    return 'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String get formattedDistance {
    if (distanceKm == null) return 'Calculando distância...';

    return '${distanceKm!.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.primary.withOpacity(.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formattedPrice,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (distanceKm != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.route_outlined,
                        size: 15,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        formattedDistance,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'ESTIMADO',
              style: TextStyle(
                color: Colors.green,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: .5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
