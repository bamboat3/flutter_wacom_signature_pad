import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_wacom_signature_pad/flutter_wacom_signature_pad.dart';

import '../../../core/providers.dart';
import '../../../core/constants/app_colors.dart';

class SignatureDialog extends ConsumerStatefulWidget {
  const SignatureDialog({super.key});

  @override
  ConsumerState<SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends ConsumerState<SignatureDialog> {
  late final WacomSignaturePadController _controller;
  bool _saveSignature = false;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(wacomPadControllerProvider);
  }

  Future<void> _handleSigned(Uint8List pngBytes) async {
    if (_saveSignature) {
      await ref.read(signatureStorageServiceProvider).saveSignature(pngBytes);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Signature Saved!")));
      }
    }

    if (mounted) {
      Navigator.of(context).pop(pngBytes);
    }
  }

  void _handleCancel() {
    if (_isClosing || !mounted) return;
    _isClosing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth < 520 ? screenWidth - 32 : 520.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      backgroundColor: AppColors.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.draw_rounded,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Sign here",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Use your Wacom pen to sign in the box",
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              WacomSignaturePad(
                width: 400,
                height: 200,
                controller: _controller,
                showControls: false,
                onSigned: _handleSigned,
                onCancel: _handleCancel,
                onClear: () {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Signature Cleared")),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: _saveSignature,
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: (v) =>
                        setState(() => _saveSignature = v ?? false),
                  ),
                  const Text(
                    "Save Signature",
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _controller.clear(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text("Clear"),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _handleCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: const Text("Cancel"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
