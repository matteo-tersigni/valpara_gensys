import 'package:flutter/material.dart';
import '../models/cane.dart';
import '../services/storage_service.dart';
import 'dart:math';

class AddCanePage extends StatefulWidget {
  const AddCanePage({super.key});

  @override
  State<AddCanePage> createState() => _AddCanePageState();
}

class _AddCanePageState extends State<AddCanePage> {
  final nome = TextEditingController();
  final razza = TextEditingController();
  final microchip = TextEditingController();

  void salva() async {
    final cane = Cane(
      id: Random().nextInt(999999).toString(),
      nome: nome.text,
      razza: razza.text,
      microchip: microchip.text,
    );

    final storage = StorageService();
    final lista = await storage.getCani();
    lista.add(cane);
    await storage.salvaCani(lista);

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nuovo Cane")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: nome, decoration: const InputDecoration(labelText: "Nome")),
            TextField(controller: razza, decoration: const InputDecoration(labelText: "Razza")),
            TextField(controller: microchip, decoration: const InputDecoration(labelText: "Microchip")),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: salva, child: const Text("Salva"))
          ],
        ),
      ),
    );
  }
}