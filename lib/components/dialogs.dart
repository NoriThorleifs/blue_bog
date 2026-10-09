import 'package:flutter/material.dart';

/// Asks before a change that would leave humans without a home.
Future<bool> confirmHumansLeave(
  BuildContext context,
  int lost,
  int total,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lose your humans?'),
        content: Text(
          lost == total
              ? 'Without housing, all $total humans in the colony will leave '
                    'the ship.'
              : '$lost of your $total humans would have no home in the '
                    'colony, and will leave the ship.',
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

/// Asks before throwing a card away for nothing.
Future<bool> confirmJettison(BuildContext context, String name) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Jettison $name?'),
        content: const Text('It\'s gone for good, and nobody pays for it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Jettison'),
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
