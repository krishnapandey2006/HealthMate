import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Floating entry point for the HealthMate assistant on native builds.
///
/// The web build uses the launcher supplied by the Noupe embed instead.
class ChatbotLauncher extends StatelessWidget {
  const ChatbotLauncher({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'HealthMate assistant',
      child: Tooltip(
        message: 'HealthMate assistant',
        excludeFromSemantics: true,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.teal,
            shape: BoxShape.circle,
            boxShadow: AppShadows.brand,
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: const SizedBox(
                width: 56,
                height: 56,
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
