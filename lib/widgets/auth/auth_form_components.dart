import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.password = false,
    this.enabled = true,
    this.email = false,
    this.errorText,
    this.autofillHints,
    this.onSubmitted,
    this.onChanged,
    this.textInputAction = TextInputAction.next,
  });
  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool password, enabled, email;
  final String? errorText;
  final Iterable<String>? autofillHints;
  final VoidCallback? onSubmitted;
  final ValueChanged<String>? onChanged;
  final TextInputAction textInputAction;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        widget.label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          letterSpacing: 1.5,
          color: AppColors.textMuted,
        ),
      ),
      const SizedBox(height: 9),
      TextFormField(
        controller: widget.controller,
        enabled: widget.enabled,
        validator: widget.validator,
        onChanged: widget.onChanged,
        obscureText: widget.password && _hidden,
        enableSuggestions: !widget.password,
        autocorrect: !widget.password && !widget.email,
        keyboardType: widget.email
            ? TextInputType.emailAddress
            : TextInputType.text,
        textInputAction: widget.textInputAction,
        autofillHints: widget.autofillHints,
        onFieldSubmitted: (_) {
          if (widget.onSubmitted != null) {
            widget.onSubmitted!();
          } else {
            FocusScope.of(context).nextFocus();
          }
        },
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: widget.email ? 'seu@email.com' : null,
          hintStyle: const TextStyle(color: AppColors.textMuted),
          errorText: widget.errorText,
          errorMaxLines: 3,
          errorStyle: const TextStyle(color: Color(0xFFFFB4AB)),
          filled: true,
          fillColor: AppColors.surfaceInput,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: AppColors.primaryLime),
          ),
          suffixIcon: widget.password
              ? IconButton(
                  tooltip: _hidden
                      ? 'Mostrar ${widget.label.toLowerCase()}'
                      : 'Ocultar ${widget.label.toLowerCase()}',
                  onPressed: widget.enabled
                      ? () => setState(() => _hidden = !_hidden)
                      : null,
                  icon: Icon(
                    _hidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                )
              : null,
        ),
      ),
    ],
  );
}

class AuthNotice extends StatelessWidget {
  const AuthNotice({super.key, required this.message, this.success = false});
  final String message;
  final bool success;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: (success ? AppColors.secondaryTeal : const Color(0xFFFFB4AB))
            .withValues(alpha: .09),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: TextStyle(
          height: 1.4,
          fontSize: 13,
          color: success ? AppColors.secondaryTeal : const Color(0xFFFFB4AB),
        ),
      ),
    ),
  );
}

class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });
  final String label;
  final bool busy;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryLime,
        foregroundColor: AppColors.textDark,
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                semanticsLabel: 'Aguarde',
              ),
            )
          : Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    ),
  );
}
