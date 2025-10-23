import 'package:flutter/material.dart';

class CustomTextField extends StatefulWidget {
  final String hint;
  final String label;
  final TextEditingController controller;
  final bool isPassword;
  final IconData? icon;

  const CustomTextField({
    super.key,
    required this.hint,
    required this.label,
    required this.controller,
    this.isPassword = false,
    this.icon,
  });

  @override
  _CustomTextFieldState createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  final FocusNode _focusNode = FocusNode();
  Color borderColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        borderColor = _focusNode.hasFocus ? Colors.blueAccent : Colors.grey;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: widget.isPassword,
      focusNode: _focusNode,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        labelStyle: TextStyle(color: _focusNode.hasFocus ? Colors.blueAccent : Colors.grey),
        prefixIcon: widget.icon != null ? Icon(widget.icon, color: borderColor) : null,
        filled: true,
        fillColor: Colors.grey[200],
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blueAccent, width: 2.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey, width: 1.5),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }
}

// 📌 Custom Phone Number TextField
class CustomPhoneTextField extends StatelessWidget {
  final String hint;
  final String label;
  final TextEditingController controller;
  final String prefixText;

  const CustomPhoneTextField({
    super.key,
    required this.hint,
    required this.label,
    required this.controller,
    this.prefixText = "",
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        filled: true,
        fillColor: Colors.grey[200],
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
