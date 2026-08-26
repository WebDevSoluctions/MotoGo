import 'package:flutter/material.dart';

import '../../../../config/colors.dart';
import '../../../../services/api_service.dart';
import '../../../../services/auth_service.dart';

class HomeHeader extends StatefulWidget {
  const HomeHeader({
    super.key,
    this.userName = '',
  });

  final String userName;

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> {
  String _name = '';

  @override
  void initState() {
    super.initState();
    _name = widget.userName;
    _loadName();
  }

  Future<void> _loadName() async {
    final id = int.tryParse(await AuthService.getUserId() ?? '');
    if (id == null) return;
    final response = await ApiService.getUserProfile(userId: id);
    final user = response['user'];
    if (!mounted || user is! Map) return;
    final name = user['name']?.toString().trim() ?? '';
    if (name.isNotEmpty) setState(() => _name = name);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [

        Container(
          width: 64,
          height: 64,

          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(.12),
            borderRadius: BorderRadius.circular(18),
          ),

          child: const Icon(
            Icons.person,
            size: 34,
            color: AppColors.primary,
          ),
        ),

        const SizedBox(width: 16),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Text(
                greeting(),
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                _name.isEmpty ? 'Olá!' : _name,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

            ],
          ),
        ),

        Container(
          width: 52,
          height: 52,

          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),

            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.05),
                blurRadius: 10,
              ),
            ],
          ),

          child: Stack(
            children: [

              const Center(
                child: Icon(
                  Icons.notifications_none_rounded,
                  size: 28,
                ),
              ),

              Positioned(
                right: 12,
                top: 12,

                child: Container(
                  width: 10,
                  height: 10,

                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),

            ],
          ),
        ),

      ],
    );
  }

  String greeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return "Bom dia 👋";
    }

    if (hour < 18) {
      return "Boa tarde 👋";
    }

    return "Boa noite 👋";
  }
}