import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int? maxLines;
  final bool enabled;
  final VoidCallback? onTap;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: AppConstants.bodyMedium.copyWith(
            fontWeight: FontWeight.w500,
            color: AppConstants.textPrimaryColor,
          ),
        ),
        const SizedBox(height: AppConstants.spacingS),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          maxLines: maxLines,
          enabled: enabled,
          onTap: onTap,
          style: AppConstants.bodyLarge.copyWith(
            color: AppConstants.textPrimaryColor,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppConstants.bodyMedium.copyWith(
              color: AppConstants.textSecondaryColor.withOpacity(0.6),
            ),
            prefixIcon: prefixIcon != null
                ? Icon(
                    prefixIcon,
                    color: AppConstants.textSecondaryColor,
                    size: 20,
                  )
                : null,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppConstants.surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
              borderSide: BorderSide(
                color: AppConstants.textSecondaryColor.withOpacity(0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
              borderSide: BorderSide(
                color: AppConstants.textSecondaryColor.withOpacity(0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
              borderSide: const BorderSide(
                color: AppConstants.primaryColor,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
              borderSide: const BorderSide(
                color: AppConstants.errorColor,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
              borderSide: const BorderSide(
                color: AppConstants.errorColor,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingM,
              vertical: AppConstants.spacingM,
            ),
          ),
        ),
      ],
    );
  }
}
