import 'package:flutter/material.dart';

import '../../../../config/colors.dart';

class PaymentCard extends StatelessWidget {
  final String selectedMethod;
  final ValueChanged<String> onChanged;

  const PaymentCard({
    super.key,
    required this.selectedMethod,
    required this.onChanged,
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          // ======================================================
          // TÍTULO
          // ======================================================

          const Text(
            'Forma de pagamento',

            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 14),

          // ======================================================
          // PIX
          // ======================================================

          _PaymentOption(
            title: 'PIX',
            subtitle: 'Pagamento instantâneo',
            icon: Icons.pix_rounded,
            value: 'pix',
            selectedValue: selectedMethod,
            onTap: () {
              onChanged('pix');
            },
          ),

          const SizedBox(height: 10),

          // ======================================================
          // DINHEIRO
          // ======================================================

          _PaymentOption(
            title: 'Dinheiro',
            subtitle: 'Pague ao motorista',
            icon: Icons.payments_outlined,
            value: 'cash',
            selectedValue: selectedMethod,
            onTap: () {
              onChanged('cash');
            },
          ),

          const SizedBox(height: 10),

          // ======================================================
          // CARTÃO
          // ======================================================

          _PaymentOption(
            title: 'Cartão',
            subtitle: 'Pagamento com cartão',
            icon: Icons.credit_card_outlined,
            value: 'card',
            selectedValue: selectedMethod,
            onTap: () {
              onChanged('card');
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================
// OPÇÃO DE PAGAMENTO
// ============================================================

class _PaymentOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String value;
  final String selectedValue;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.selectedValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool selected =
        value == selectedValue;

    return InkWell(
      onTap: onTap,

      borderRadius:
          BorderRadius.circular(14),

      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 180),

        padding:
            const EdgeInsets.all(13),

        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.08)
              : Colors.grey.withOpacity(0.04),

          borderRadius:
              BorderRadius.circular(14),

          border: Border.all(
            color: selected
                ? AppColors.primary
                : Colors.grey.withOpacity(0.15),

            width: selected ? 1.5 : 1,
          ),
        ),

        child: Row(
          children: [
            // ==================================================
            // ÍCONE
            // ==================================================

            Container(
              width: 44,
              height: 44,

              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withOpacity(0.12)
                    : Colors.grey.withOpacity(0.08),

                borderRadius:
                    BorderRadius.circular(12),
              ),

              child: Icon(
                icon,

                color: selected
                    ? AppColors.primary
                    : Colors.grey.shade700,

                size: 24,
              ),
            ),

            const SizedBox(width: 13),

            // ==================================================
            // TEXTO
            // ==================================================

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  Text(
                    title,

                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    subtitle,

                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
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
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,

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