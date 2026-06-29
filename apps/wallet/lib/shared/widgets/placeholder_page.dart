import 'package:flutter/material.dart';
import '../../app/theme/calm_tokens.dart';
import '../../l10n/app_localizations.dart';

/// A stub body for a navigation destination that exists in the shell but isn't
/// built yet — an icon, the section name, and a "coming soon" line. Returns body
/// content only (no Scaffold/AppBar); the shell supplies the chrome. Remove a
/// screen's use of this as its real content lands.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontFamily: CalmTokens.fontDisplay,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.comingSoon,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
