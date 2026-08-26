import 'package:flutter/material.dart';

import '../../../config/colors.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Forma de Pagamento',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 18),
        _paymentItem(
          value: 'pix',
          title: 'PIX',
          subtitle: 'Pagamento instantâneo',
          icon: Icons.pix,
          color: Colors.green,
        ),
        const SizedBox(height: 14),
        _paymentItem(
          value: 'cash',
          title: 'Dinheiro',
          subtitle: 'Pagar ao motorista',
          icon: Icons.attach_money,
          color: Colors.orange,
        ),
        const SizedBox(height: 14),
        _paymentItem(
          value: 'card',
          title: 'Cartão',
          subtitle: 'Crédito ou débito',
          icon: Icons.credit_card,
          color: Colors.blue,
        ),
      ],
    );
  }

  Widget _paymentItem({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final selected = selectedMethod == value;

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(.12) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: color.withOpacity(.12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: selectedMethod,
              activeColor: AppColors.primary,
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ],
        ),
      ),
    );
  }
}
