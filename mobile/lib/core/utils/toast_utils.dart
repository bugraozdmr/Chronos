import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

enum ChronosToastType { success, error, info, warning }

ToastificationType _mapToastType(ChronosToastType type) {
  switch (type) {
    case ChronosToastType.success:
      return ToastificationType.success;
    case ChronosToastType.error:
      return ToastificationType.error;
    case ChronosToastType.info:
      return ToastificationType.info;
    case ChronosToastType.warning:
      return ToastificationType.warning;
  }
}

void showChronosToast({
  required BuildContext context,
  required String title,
  required String description,
  ChronosToastType type = ChronosToastType.info,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  toastification.show(
    context: context,
    type: _mapToastType(type),
    style: ToastificationStyle.minimal,
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    description: Text(description, style: const TextStyle(fontSize: 13)),
    alignment: Alignment.bottomCenter,
    margin: const EdgeInsets.only(bottom: 104, left: 24, right: 24),
    autoCloseDuration: const Duration(seconds: 3),
    showProgressBar: false,
    closeButtonShowType: CloseButtonShowType.none,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
        blurRadius: 20,
        offset: const Offset(0, 8),
      )
    ],
  );
}
