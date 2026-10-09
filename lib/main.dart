import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'components/theme.dart';
import 'functions/sound.dart';
import 'routing_table.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SoundBoard.instance.init();
  runApp(const ProviderScope(child: BlueBogApp()));
}

class BlueBogApp extends ConsumerWidget {
  const BlueBogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Blue Bog',
    debugShowCheckedModeBanner: false,
    theme: appTheme,
    routerConfig: ref.watch(routerProvider),
  );
}
