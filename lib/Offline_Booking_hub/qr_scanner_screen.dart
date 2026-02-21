import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrGenerateScreen extends StatelessWidget {
  final String data;

  const QrGenerateScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: QrImageView(
          data: data,
          version: QrVersions.auto,
          size: 250,
        ),
      ),
    );
  }
}