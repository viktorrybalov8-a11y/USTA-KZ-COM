import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/job_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JobRepository.instance.initialize();
  runApp(const UstaApp());
}

class UstaApp extends StatelessWidget {
  const UstaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'USTA.KZ',
    theme: ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF146B5A),
      scaffoldBackgroundColor: const Color(0xFFF5F7F6),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF5F7F6),
        surfaceTintColor: Colors.transparent,
      ),
    ),
    home: const HomeScreen(),
  );
}
