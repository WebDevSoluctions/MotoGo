import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;

  final String hint;

  final IconData icon;

  final bool obscure;

  final Widget? suffixIcon;

  final TextInputType keyboardType;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,

      obscureText: obscure,

      keyboardType: keyboardType,

      decoration: InputDecoration(
        hintText: hint,

        prefixIcon: Icon(icon),

        suffixIcon: suffixIcon,
      ),
    );
  }
}