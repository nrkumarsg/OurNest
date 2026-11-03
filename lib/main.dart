import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/constants/env.dart';
import 'core/network/supabase_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error: ${details.exception}');
  };

  try {
    // 1. Initialize environment variables
    await Env.init();
  } catch (_) {}

  try {
    // 2. Initialize Supabase Client
    await SupabaseService.init();
  } catch (_) {}

  // 3. Launch App inside Riverpod ProviderScope
  runApp(
    const ProviderScope(
      child: OurNestApp(),
    ),
  );
}
