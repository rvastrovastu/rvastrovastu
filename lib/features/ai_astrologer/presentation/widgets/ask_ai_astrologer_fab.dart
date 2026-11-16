// lib/features/ai_astrologer/presentation/widgets/ask_ai_astrologer_fab.dart
//
// Round floating "Ask AI" button with a gold-to-lilac glow. Opens the AI chat at /ask.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';

class AskAiAstrologerFab extends StatelessWidget {
  const AskAiAstrologerFab({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Ask AI Astrologer',
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.push('/ask'),
            child: Ink(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, color: AppColors.onPrimary, size: 22),
                  SizedBox(height: 2),
                  Text(
                    'Ask AI',
                    style: TextStyle(
                      color: AppColors.onPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
