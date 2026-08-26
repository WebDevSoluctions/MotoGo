import 'package:flutter/material.dart';

import '../../../../config/colors.dart';
import '../../../../services/api_service.dart';
import '../../../../services/auth_service.dart';

class BottomPanel extends StatelessWidget {
  const BottomPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(22),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(32),
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 25,
            offset: const Offset(0, -5),
          ),
        ],
      ),

      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Center(
            child: Container(
              width: 60,
              height: 6,

              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),

          const SizedBox(height: 25),

          const Text(
            "Para onde você deseja ir?",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            "Escolha um destino para iniciar sua viagem.",
            style: TextStyle(
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 25),

          _addressTile(
            icon: Icons.my_location,
            color: Colors.green,
            title: "Origem",
            subtitle: "Sua localização atual",
          ),

          const SizedBox(height: 16),

          _addressTile(
            icon: Icons.location_on,
            color: Colors.red,
            title: "Destino",
            subtitle: "Selecionar destino",
          ),

          const SizedBox(height: 25),

          const SizedBox(height: 25),

          SizedBox(
            width: double.infinity,
            height: 58,

            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),

              onPressed: () {},

              icon: const Icon(
                Icons.search,
                color: Colors.white,
              ),

              label: const Text(
                "Procurar Mototáxi",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

        ],
      ),
    );
  }

  static Widget _addressTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
      ),

      child: Row(
        children: [

          CircleAvatar(
            radius: 24,
            backgroundColor: color.withOpacity(.15),

            child: Icon(
              icon,
              color: color,
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
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.grey,
                  ),
                ),

              ],
            ),
          ),

          const Icon(
            Icons.arrow_forward_ios,
            size: 16,
          ),

        ],
      ),
    );
  }
}