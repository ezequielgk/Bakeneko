import 'package:flutter/material.dart';

class EmptyStateAction extends StatelessWidget {
  const EmptyStateAction({
    super.key,
    required this.icon,
    required this.message,
    required this.buttonText,
    required this.onPressed,
  });

  final IconData icon;
  final String message;
  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.explore),
            label: Text(buttonText),
          ),
        ],
      ),
    );
  }
}
