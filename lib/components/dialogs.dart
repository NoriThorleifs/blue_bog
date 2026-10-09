import 'package:flutter/material.dart';

/// Asks before a change that would send humans away.
Future<bool> confirmCrewLoss(BuildContext context, int lost, int total) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lose your humans?'),
        content: Text(
          lost == total
              ? 'Without accommodation, all $total humans aboard will leave '
                    'the ship.'
              : '$lost of your $total humans would have no berth, and will '
                    'leave the ship.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep them'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Let them go'),
          ),
        ],
      ),
    ) ??
    false;

void showError(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

/// Shows [error] if an action was refused.
void reportError(BuildContext context, String? error) {
  if (error != null) showError(context, error);
}
