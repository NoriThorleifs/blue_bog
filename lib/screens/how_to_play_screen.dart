import 'package:flutter/material.dart';

import '../components/guide/guide_basics.dart';
import '../components/guide/guide_world.dart';

/// The user guide: the rules and ideas of the game, with the cards and
/// layouts it talks about shown as they look in play.
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('How to play')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [...guideBasics(), ...guideWorld()],
          ),
        ),
      ),
    ),
  );
}
