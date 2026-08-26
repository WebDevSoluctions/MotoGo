import 'package:flutter/material.dart';

class BottomMenu extends StatelessWidget {
  const BottomMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: 0,
      destinations: const [

        NavigationDestination(
          icon: Icon(Icons.home),
          label: "Home",
        ),

        NavigationDestination(
          icon: Icon(Icons.history),
          label: "Histórico",
        ),

        NavigationDestination(
          icon: Icon(Icons.favorite),
          label: "Favoritos",
        ),

        NavigationDestination(
          icon: Icon(Icons.person),
          label: "Perfil",
        ),
      ],
    );
  }
}