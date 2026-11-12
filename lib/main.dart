import 'package:flutter/material.dart';

import 'app/bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = await tryInitializeAuthentication();
  runApp(FinovaBootstrap(initialController: controller));
}
