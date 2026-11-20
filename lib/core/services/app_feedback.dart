import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

enum FeedbackKind { info, success, error }

abstract final class AppFeedback {
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  static void show(String message, {FeedbackKind kind = FeedbackKind.info}) {
    final messenger = messengerKey.currentState;
    if (messenger == null || !messenger.mounted) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: switch (kind) {
          FeedbackKind.info => AppColors.secondaryText,
          FeedbackKind.success => AppColors.positive,
          FeedbackKind.error => AppColors.negative,
        },
        duration: const Duration(seconds: 4),
        showCloseIcon: true,
        closeIconColor: Colors.white,
      ),
    );
  }
}
