import 'package:flutter/material.dart';

final appScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showPushBanner(String title, String body) {
  final messenger = appScaffoldMessengerKey.currentState;
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
}
