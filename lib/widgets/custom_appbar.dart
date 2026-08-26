import 'package:flutter/material.dart';

import '../config/colors.dart';

class CustomAppBar extends StatelessWidget
    implements PreferredSizeWidget {

  final String title;

  const CustomAppBar({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 75,
      backgroundColor: Colors.white,
      elevation: 0,

      title: Row(
        children: [

          Container(
            width: 46,
            height: 46,

            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
            ),

            child: const Icon(
              Icons.two_wheeler_rounded,
              color: Colors.white,
            ),
          ),

          const SizedBox(width: 14),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),

              const Text(
                "Mobilidade Inteligente",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),

            ],
          )

        ],
      ),

      actions: [

        Container(
          margin: const EdgeInsets.only(right: 10),

          child: Stack(
            children: [

              IconButton(
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.black,
                  size: 30,
                ),
                onPressed: () {},
              ),

              Positioned(
                right: 10,
                top: 10,

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

        Padding(
          padding: const EdgeInsets.only(
            right: 20,
            left: 6,
          ),

          child: GestureDetector(
            onTap: () {},

            child: Container(
              width: 46,
              height: 46,

              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(.15),
                borderRadius: BorderRadius.circular(14),
              ),

              child: const Icon(
                Icons.person,
                color: AppColors.primary,
              ),
            ),
          ),
        ),

      ],

      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),

        child: Container(
          color: Colors.grey.shade200,
          height: 1,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(76);
}