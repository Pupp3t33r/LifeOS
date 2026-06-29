import 'package:flutter/material.dart';
import '../../app/theme/calm_tokens.dart';

/// The "wallet." wordmark — the brand lockup shown in app bars (onboarding and
/// the main shell). The trailing dot wears the brand primary. Brand text, so the
/// word itself is intentionally not localized.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RichText(
      text: TextSpan(
        style: theme.textTheme.titleLarge?.copyWith(
          fontFamily: CalmTokens.fontDisplay,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface,
        ),
        children: [
          const TextSpan(text: 'wallet'),
          TextSpan(text: '.', style: TextStyle(color: theme.colorScheme.primary)),
        ],
      ),
    );
  }
}
