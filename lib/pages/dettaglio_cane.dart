import 'package:flutter/material.dart';
import '../models/cane.dart';

class DettaglioCane extends StatelessWidget {
  final Cane cane;

  const DettaglioCane({super.key, required this.cane});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(cane.nome)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Nome: ${cane.nome}"),
            Text("Razza: ${cane.razza}"),
            Text("Microchip: ${cane.microchip}"),
          ],
        ),
      ),
    );
  }
}