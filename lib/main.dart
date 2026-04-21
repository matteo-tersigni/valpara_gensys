import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:webview_flutter/webview_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  runApp(const ValparaGenSysApp());
}

class ValparaGenSysApp extends StatelessWidget {
  const ValparaGenSysApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Valpara Gensys',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

enum DogSex { male, female }

enum HealthStatus { ok, warning, expired }

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await plugin.initialize(
  settings: initSettings,
);

    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> rescheduleAllNotifications(List<Dog> dogs) async {
    await plugin.cancelAll();
    final now = DateTime.now();

    for (final dog in dogs) {
      for (int i = 0; i < dog.medicalEntries.length; i++) {
        final entry = dog.medicalEntries[i];
        if (entry.nextDue == null) continue;

        final due = DateTime(
          entry.nextDue!.year,
          entry.nextDue!.month,
          entry.nextDue!.day,
          9,
        );

        final reminders = <Map<String, dynamic>>[
          {'daysBefore': 30, 'label': 'tra 30 giorni'},
          {'daysBefore': 7, 'label': 'tra 7 giorni'},
          {'daysBefore': 1, 'label': 'domani'},
          {'daysBefore': 0, 'label': 'oggi'},
        ];

        for (int r = 0; r < reminders.length; r++) {
          final scheduleDate =
              due.subtract(Duration(days: reminders[r]['daysBefore'] as int));

          if (!scheduleDate.isAfter(now)) continue;

          await plugin.zonedSchedule(
  id: _notificationId(dog.id, i, r),
  title: 'Scadenza ${entry.type}',
  body:
      '${dog.name}: ${entry.description.isEmpty ? entry.type : entry.description} ${reminders[r]['label']}',
  scheduledDate: tz.TZDateTime.from(scheduleDate, tz.local),
  notificationDetails: const NotificationDetails(
    android: AndroidNotificationDetails(
      'valpara_scadenze',
      'Scadenze sanitarie',
      channelDescription:
          'Promemoria per vaccini, sverminazioni e altre scadenze',
      importance: Importance.max,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  ),
  androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
);
        }
      }
    }
  }

  int _notificationId(String dogId, int entryIndex, int reminderIndex) {
    final dogHash = dogId.hashCode.abs() % 100000;
    return dogHash * 100 + entryIndex * 10 + reminderIndex;
  }
}

class MedicalEntry {
  final String type;
  final String description;
  final DateTime date;
  final DateTime? nextDue;

  MedicalEntry({
    required this.type,
    required this.description,
    required this.date,
    this.nextDue,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'description': description,
      'date': date.toIso8601String(),
      'nextDue': nextDue?.toIso8601String(),
    };
  }

  factory MedicalEntry.fromJson(Map<String, dynamic> json) {
    return MedicalEntry(
      type: json['type'] as String? ?? '',
      description: json['description'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      nextDue: json['nextDue'] == null
          ? null
          : DateTime.tryParse(json['nextDue'] as String),
    );
  }
}

class AttachmentItem {
  final String name;
  final String type;
  final String path;
  final String section;

  AttachmentItem({
    required this.name,
    required this.type,
    required this.path,
    required this.section,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'path': path,
      'section': section,
    };
  }

  factory AttachmentItem.fromJson(Map<String, dynamic> json) {
    return AttachmentItem(
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? '',
      path: json['path'] as String? ?? '',
      section: json['section'] as String? ?? 'Generale',
    );
  }
}

class ExpenseItem {
  final String category;
  final String description;
  final double amount;
  final DateTime date;

  ExpenseItem({
    required this.category,
    required this.description,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'description': description,
      'amount': amount,
      'date': date.toIso8601String(),
    };
  }

  factory ExpenseItem.fromJson(Map<String, dynamic> json) {
    return ExpenseItem(
      category: json['category'] as String? ?? '',
      description: json['description'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class GenealogyData {
  String sire;
  String dam;
  String paternalGrandfather;
  String paternalGrandmother;
  String maternalGrandfather;
  String maternalGrandmother;
  List<String> greatGrandparents;
  List<String> greatGreatGrandparents;
  List<String> pedigreeAttachments;

  GenealogyData({
    this.sire = '',
    this.dam = '',
    this.paternalGrandfather = '',
    this.paternalGrandmother = '',
    this.maternalGrandfather = '',
    this.maternalGrandmother = '',
    List<String>? greatGrandparents,
    List<String>? greatGreatGrandparents,
    List<String>? pedigreeAttachments,
  })  : greatGrandparents = greatGrandparents ?? List.filled(8, ''),
        greatGreatGrandparents = greatGreatGrandparents ?? List.filled(16, ''),
        pedigreeAttachments = pedigreeAttachments ?? [];

  Map<String, dynamic> toJson() {
    return {
      'sire': sire,
      'dam': dam,
      'paternalGrandfather': paternalGrandfather,
      'paternalGrandmother': paternalGrandmother,
      'maternalGrandfather': maternalGrandfather,
      'maternalGrandmother': maternalGrandmother,
      'greatGrandparents': greatGrandparents,
      'greatGreatGrandparents': greatGreatGrandparents,
      'pedigreeAttachments': pedigreeAttachments,
    };
  }

  factory GenealogyData.fromJson(Map<String, dynamic> json) {
    return GenealogyData(
      sire: json['sire'] as String? ?? '',
      dam: json['dam'] as String? ?? '',
      paternalGrandfather: json['paternalGrandfather'] as String? ?? '',
      paternalGrandmother: json['paternalGrandmother'] as String? ?? '',
      maternalGrandfather: json['maternalGrandfather'] as String? ?? '',
      maternalGrandmother: json['maternalGrandmother'] as String? ?? '',
      greatGrandparents: (json['greatGrandparents'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          List.filled(8, ''),
      greatGreatGrandparents: (json['greatGreatGrandparents'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          List.filled(16, ''),
      pedigreeAttachments: (json['pedigreeAttachments'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class PedigreeNode {
  String code;
  String name;
  String sex;
  int generation;
  String roleKey;

  PedigreeNode({
    required this.code,
    required this.name,
    required this.sex,
    required this.generation,
    required this.roleKey,
  });

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'sex': sex,
      'generation': generation,
      'roleKey': roleKey,
    };
  }

  factory PedigreeNode.fromJson(Map<String, dynamic> json) {
    return PedigreeNode(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      sex: json['sex'] as String? ?? '',
      generation: json['generation'] as int? ?? 0,
      roleKey: json['roleKey'] as String? ?? '',
    );
  }
}

class InbreedingResult {
  final double coefficient;
  final List<String> repeatedAncestors;

  InbreedingResult({
    required this.coefficient,
    required this.repeatedAncestors,
  });
}

class Dog {
  final String id;
  String name;
  String breed;
  String microchip;
  String roi;
  DogSex sex;
  DateTime? birthDate;
  List<MedicalEntry> medicalEntries;
  List<AttachmentItem> attachments;
  List<ExpenseItem> expenses;
  DateTime? lastHeatDate;
  DateTime? nextEstimatedHeatDate;
  List<String> litters;
  GenealogyData genealogy;
  List<PedigreeNode> pedigreeNodes;
  double inbreedingCoefficient;

  Dog({
    required this.id,
    required this.name,
    required this.breed,
    required this.microchip,
    required this.roi,
    required this.sex,
    this.birthDate,
    List<MedicalEntry>? medicalEntries,
    List<AttachmentItem>? attachments,
    List<ExpenseItem>? expenses,
    this.lastHeatDate,
    this.nextEstimatedHeatDate,
    List<String>? litters,
    GenealogyData? genealogy,
    List<PedigreeNode>? pedigreeNodes,
    this.inbreedingCoefficient = 0,
  })  : medicalEntries = medicalEntries ?? [],
        attachments = attachments ?? [],
        expenses = expenses ?? [],
        litters = litters ?? [],
        genealogy = genealogy ?? GenealogyData(),
        pedigreeNodes = pedigreeNodes ?? [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'breed': breed,
      'microchip': microchip,
      'roi': roi,
      'sex': sex.index,
      'birthDate': birthDate?.toIso8601String(),
      'medicalEntries': medicalEntries.map((e) => e.toJson()).toList(),
      'attachments': attachments.map((e) => e.toJson()).toList(),
      'expenses': expenses.map((e) => e.toJson()).toList(),
      'lastHeatDate': lastHeatDate?.toIso8601String(),
      'nextEstimatedHeatDate': nextEstimatedHeatDate?.toIso8601String(),
      'litters': litters,
      'genealogy': genealogy.toJson(),
      'pedigreeNodes': pedigreeNodes.map((e) => e.toJson()).toList(),
      'inbreedingCoefficient': inbreedingCoefficient,
    };
  }

  factory Dog.fromJson(Map<String, dynamic> json) {
    return Dog(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      breed: json['breed'] as String? ?? '',
      microchip: json['microchip'] as String? ?? '',
      roi: json['roi'] as String? ?? '',
      sex: DogSex.values[(json['sex'] as int?) ?? 0],
      birthDate: json['birthDate'] == null
          ? null
          : DateTime.tryParse(json['birthDate'] as String),
      medicalEntries: (json['medicalEntries'] as List?)
              ?.map((e) => MedicalEntry.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      attachments: (json['attachments'] as List?)
              ?.map((e) => AttachmentItem.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      expenses: (json['expenses'] as List?)
              ?.map((e) => ExpenseItem.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      lastHeatDate: json['lastHeatDate'] == null
          ? null
          : DateTime.tryParse(json['lastHeatDate'] as String),
      nextEstimatedHeatDate: json['nextEstimatedHeatDate'] == null
          ? null
          : DateTime.tryParse(json['nextEstimatedHeatDate'] as String),
      litters:
          (json['litters'] as List?)?.map((e) => e.toString()).toList() ?? [],
      genealogy: json['genealogy'] == null
          ? GenealogyData()
          : GenealogyData.fromJson(Map<String, dynamic>.from(json['genealogy'])),
      pedigreeNodes: (json['pedigreeNodes'] as List?)
              ?.map((e) => PedigreeNode.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      inbreedingCoefficient:
          (json['inbreedingCoefficient'] as num?)?.toDouble() ?? 0,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String kennelName = 'Il mio allevamento';
  String searchText = '';
  bool dataLoaded = false;
  List<Dog> dogs = [];

  @override
  void initState() {
    super.initState();
    loadAllData();
  }

  List<Dog> buildDefaultDogs() {
    return [
      Dog(
        id: 'DOG-001',
        name: 'Argo',
        breed: 'Segugio Italiano',
        microchip: '380260000000001',
        roi: 'LO000001',
        sex: DogSex.male,
        birthDate: DateTime.now().subtract(const Duration(days: 900)),
        medicalEntries: [
          MedicalEntry(
            type: 'Vaccino',
            description: 'Richiamo annuale',
            date: DateTime.now().subtract(const Duration(days: 320)),
            nextDue: DateTime.now().add(const Duration(days: 20)),
          ),
        ],
      ),
      Dog(
        id: 'DOG-002',
        name: 'Luna',
        breed: 'Segugio Italiano',
        microchip: '380260000000002',
        roi: 'LO000002',
        sex: DogSex.female,
        birthDate: DateTime.now().subtract(const Duration(days: 1100)),
      ),
    ];
  }

  String formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  DateTime? parseDate(String value) {
    if (value.trim().isEmpty) return null;
    try {
      final parts = value.split('/');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      }
    } catch (_) {}
    return DateTime.tryParse(value);
  }

  List<Dog> get filteredDogs {
    if (searchText.trim().isEmpty) return dogs;
    final q = searchText.toLowerCase().trim();
    return dogs.where((dog) {
      return dog.name.toLowerCase().contains(q) ||
          dog.breed.toLowerCase().contains(q) ||
          dog.microchip.toLowerCase().contains(q) ||
          dog.roi.toLowerCase().contains(q) ||
          dog.id.toLowerCase().contains(q);
    }).toList();
  }

  HealthStatus getDogHealthStatus(Dog dog) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final dueDates = dog.medicalEntries
        .map((e) => e.nextDue)
        .whereType<DateTime>()
        .toList();

    if (dueDates.isEmpty) return HealthStatus.ok;
    if (dueDates.any((d) => d.isBefore(today))) return HealthStatus.expired;
    if (dueDates.any((d) => d.difference(today).inDays <= 30)) {
      return HealthStatus.warning;
    }
    return HealthStatus.ok;
  }

  Color getStatusColor(HealthStatus status) {
    switch (status) {
      case HealthStatus.ok:
        return Colors.green;
      case HealthStatus.warning:
        return Colors.orange;
      case HealthStatus.expired:
        return Colors.red;
    }
  }

  String getStatusLabel(HealthStatus status) {
    switch (status) {
      case HealthStatus.ok:
        return 'OK';
      case HealthStatus.warning:
        return 'In scadenza';
      case HealthStatus.expired:
        return 'Scaduto';
    }
  }

  Color getSexColor(Dog dog) {
    return dog.sex == DogSex.male
        ? const Color.fromARGB(145, 120, 195, 255)
        : const Color.fromARGB(145, 255, 170, 210);
  }

  Future<void> saveAllData() async {
    final prefs = await SharedPreferences.getInstance();
    final dogsData = dogs.map((d) => jsonEncode(d.toJson())).toList();
    await prefs.setStringList('dogs', dogsData);
    await prefs.setString('kennelName', kennelName);
    await prefs.setBool('hasInitializedData', true);
    await NotificationService.instance.rescheduleAllNotifications(dogs);
  }

  Future<void> loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    final hasInitializedData = prefs.getBool('hasInitializedData') ?? false;
    final savedKennelName = prefs.getString('kennelName');
    final dogsData = prefs.getStringList('dogs');

    setState(() {
      kennelName = savedKennelName ?? 'Il mio allevamento';
      if (!hasInitializedData) {
        dogs = buildDefaultDogs();
      } else {
        dogs = (dogsData ?? [])
            .map((item) => Dog.fromJson(jsonDecode(item)))
            .toList();
      }
      dataLoaded = true;
    });

    await NotificationService.instance.rescheduleAllNotifications(dogs);

    if (!hasInitializedData) {
      await saveAllData();
    }
  }

  void editKennelName() {
    final controller = TextEditingController(text: kennelName);

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nome allevamento'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Inserisci il nome allevamento',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  kennelName = controller.text.trim();
                });
                await saveAllData();
              }
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  void openAddDogDialog() {
    final nameController = TextEditingController();
    final breedController = TextEditingController();
    final microchipController = TextEditingController();
    final roiController = TextEditingController();
    final birthDateController = TextEditingController();
    DogSex selectedSex = DogSex.male;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Nuovo cane'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: breedController,
                  decoration: const InputDecoration(labelText: 'Razza'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: microchipController,
                  decoration: const InputDecoration(labelText: 'Microchip'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: roiController,
                  decoration: const InputDecoration(labelText: 'ROI / RSR'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: birthDateController,
                  decoration: const InputDecoration(
                    labelText: 'Data di nascita (gg/mm/aaaa)',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<DogSex>(
                  initialValue: selectedSex,
                  decoration: const InputDecoration(labelText: 'Sesso'),
                  items: const [
                    DropdownMenuItem(
                      value: DogSex.male,
                      child: Text('Maschio'),
                    ),
                    DropdownMenuItem(
                      value: DogSex.female,
                      child: Text('Femmina'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setLocalState(() => selectedSex = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;

                setState(() {
                  dogs.add(
                    Dog(
                      id:
                          'DOG-${(DateTime.now().millisecondsSinceEpoch % 1000000)}',
                      name: nameController.text.trim(),
                      breed: breedController.text.trim().isEmpty
                          ? 'Non specificata'
                          : breedController.text.trim(),
                      microchip: microchipController.text.trim(),
                      roi: roiController.text.trim(),
                      birthDate: parseDate(birthDateController.text),
                      sex: selectedSex,
                    ),
                  );
                });

                await saveAllData();
                if (!mounted) return;
                Navigator.pop(dialogContext);
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
  }

  void editDog(Dog dog) {
    final nameController = TextEditingController(text: dog.name);
    final breedController = TextEditingController(text: dog.breed);
    final microchipController = TextEditingController(text: dog.microchip);
    final roiController = TextEditingController(text: dog.roi);
    final birthDateController = TextEditingController(text: formatDate(dog.birthDate));
    DogSex selectedSex = dog.sex;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Modifica cane'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: breedController,
                  decoration: const InputDecoration(labelText: 'Razza'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: microchipController,
                  decoration: const InputDecoration(labelText: 'Microchip'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: roiController,
                  decoration: const InputDecoration(labelText: 'ROI / RSR'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: birthDateController,
                  decoration: const InputDecoration(
                    labelText: 'Data di nascita (gg/mm/aaaa)',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<DogSex>(
                  initialValue: selectedSex,
                  decoration: const InputDecoration(labelText: 'Sesso'),
                  items: const [
                    DropdownMenuItem(
                      value: DogSex.male,
                      child: Text('Maschio'),
                    ),
                    DropdownMenuItem(
                      value: DogSex.female,
                      child: Text('Femmina'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setLocalState(() => selectedSex = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;

                setState(() {
                  dog.name = nameController.text.trim();
                  dog.breed = breedController.text.trim().isEmpty
                      ? 'Non specificata'
                      : breedController.text.trim();
                  dog.microchip = microchipController.text.trim();
                  dog.roi = roiController.text.trim();
                  dog.birthDate = parseDate(birthDateController.text);
                  dog.sex = selectedSex;
                });

                await saveAllData();
                if (!mounted) return;
                Navigator.pop(dialogContext);
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
  }

  void deleteDog(Dog dog) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Elimina cane'),
        content: Text('Vuoi eliminare ${dog.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              setState(() {
                dogs.removeWhere((d) => d.id == dog.id);
              });
              await saveAllData();
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  void showDogQr(Dog dog) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('QR Code - ${dog.name}'),
        content: SizedBox(
          width: 260,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: dog.id,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                'Codice: ${dog.id}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  void openDogDetails(Dog dog) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DogDetailsPage(
          dog: dog,
          status: getDogHealthStatus(dog),
          onDataChanged: () async {
            setState(() {});
            await saveAllData();
          },
        ),
      ),
    ).then((_) async {
      setState(() {});
      await saveAllData();
    });
  }

  void openScanner() async {
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );

    if (!mounted || scannedCode == null) return;

    final foundDog = dogs.where((d) => d.id == scannedCode).firstOrNull;

    if (foundDog == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nessun cane trovato per QR: $scannedCode')),
      );
      return;
    }

    openDogDetails(foundDog);
  }

  @override
  Widget build(BuildContext context) {
    if (!dataLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEAF1EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF1EF),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: GestureDetector(
          onTap: editKennelName,
          child: Text(
            kennelName,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: Opacity(
              opacity: 0.28,
              child: Image.asset(
                'assets/images/logo_valpara.jpeg',
                width: 700,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: TextField(
                  onChanged: (value) => setState(() => searchText = value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Cerca cane',
                    filled: true,
                    fillColor: Colors.white.withAlpha(209),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: filteredDogs.isEmpty
                    ? const Center(child: Text('Nessun cane trovato'))
                    : ListView.builder(
                        itemCount: filteredDogs.length,
                        itemBuilder: (context, index) {
                          final dog = filteredDogs[index];
                          final status = getDogHealthStatus(dog);
                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: getSexColor(dog),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              leading: CircleAvatar(
                                radius: 12,
                                backgroundColor: getStatusColor(status),
                              ),
                              title: Text(
                                dog.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              subtitle: Text(
                                '${dog.breed} • ${getStatusLabel(status)}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => editDog(dog),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.qr_code_2),
                                    onPressed: () => showDogQr(dog),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => deleteDog(dog),
                                  ),
                                ],
                              ),
                              onTap: () => openDogDetails(dog),
                            ),
                          );
                        },
                      ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, 14),
                child: Text(
                  'Realizzato da Allevamento della Valpara',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'scan_qr',
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            onPressed: openScanner,
            child: const Icon(Icons.qr_code_scanner),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.small(
            heroTag: 'add_dog',
            backgroundColor: const Color(0xFFAEEDE4),
            foregroundColor: Colors.black87,
            onPressed: openAddDogDialog,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class DogDetailsPage extends StatefulWidget {
  final Dog dog;
  final HealthStatus status;
  final Future<void> Function() onDataChanged;

  const DogDetailsPage({
    super.key,
    required this.dog,
    required this.status,
    required this.onDataChanged,
  });

  @override
  State<DogDetailsPage> createState() => _DogDetailsPageState();
}

class _DogDetailsPageState extends State<DogDetailsPage> {
  final ImagePicker _imagePicker = ImagePicker();

  String formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  DateTime? parseDate(String value) {
    if (value.trim().isEmpty) return null;
    try {
      final parts = value.split('/');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      }
    } catch (_) {}
    return DateTime.tryParse(value);
  }

  String sexLabel(DogSex sex) {
    return sex == DogSex.male ? 'Maschio' : 'Femmina';
  }

  String healthText(HealthStatus status) {
    switch (status) {
      case HealthStatus.ok:
        return 'Tutto regolare';
      case HealthStatus.warning:
        return 'Scadenza vicina';
      case HealthStatus.expired:
        return 'Scadenza superata';
    }
  }

  String formatMoney(double value) {
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }

  List<AttachmentItem> sectionAttachments(String section) {
    return widget.dog.attachments.where((a) => a.section == section).toList();
  }

  double get totalExpenses {
    return widget.dog.expenses.fold(0, (sum, item) => sum + item.amount);
  }

  String roleLabel(String roleKey) {
    switch (roleKey) {
      case 'self':
        return 'Soggetto';
      case 'sire':
        return 'Padre';
      case 'dam':
        return 'Madre';
      case 'pgf':
        return 'Nonno paterno';
      case 'pgm':
        return 'Nonna paterna';
      case 'mgf':
        return 'Nonno materno';
      case 'mgm':
        return 'Nonna materna';
      default:
        if (roleKey.startsWith('g')) {
          return 'Ascendente ${roleKey.substring(1)}';
        }
        return roleKey;
    }
  }

  int generationFromRole(String roleKey) {
    switch (roleKey) {
      case 'self':
        return 0;
      case 'sire':
      case 'dam':
        return 1;
      case 'pgf':
      case 'pgm':
      case 'mgf':
      case 'mgm':
        return 2;
      default:
        if (roleKey.startsWith('g')) {
          final n = int.tryParse(roleKey.substring(1)) ?? 0;
          if (n >= 1 && n <= 8) return 3;
          if (n >= 9) return 4;
        }
        return 0;
    }
  }

  InbreedingResult calculateInbreedingFromVisiblePedigree(List<PedigreeNode> nodes) {
    final counts = <String, int>{};

    for (final n in nodes) {
      if (n.roleKey == 'self') continue;
      final code = n.code.trim().toUpperCase();
      if (code.isEmpty) continue;
      counts[code] = (counts[code] ?? 0) + 1;
    }

    final repeated = counts.entries
        .where((e) => e.value > 1)
        .map((e) => e.key)
        .toList();

    double coeff = 0;
    for (final n in nodes) {
      if (n.roleKey == 'self') continue;
      final code = n.code.trim().toUpperCase();
      if (code.isEmpty) continue;
      if ((counts[code] ?? 0) > 1) {
        coeff += math.pow(0.5, n.generation * 2 + 1).toDouble();
      }
    }

    if (coeff > 1) coeff = 1;

    return InbreedingResult(
      coefficient: coeff * 100,
      repeatedAncestors: repeated,
    );
  }

  Future<void> editAnagrafica() async {
    final nameController = TextEditingController(text: widget.dog.name);
    final breedController = TextEditingController(text: widget.dog.breed);
    final microchipController = TextEditingController(text: widget.dog.microchip);
    final roiController = TextEditingController(text: widget.dog.roi);
    final birthDateController =
        TextEditingController(text: formatDate(widget.dog.birthDate));
    DogSex selectedSex = widget.dog.sex;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Modifica anagrafica'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: breedController,
                  decoration: const InputDecoration(labelText: 'Razza'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: microchipController,
                  decoration: const InputDecoration(labelText: 'Microchip'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: roiController,
                  decoration: const InputDecoration(labelText: 'ROI / RSR'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: birthDateController,
                  decoration: const InputDecoration(
                    labelText: 'Data di nascita (gg/mm/aaaa)',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<DogSex>(
                  initialValue: selectedSex,
                  decoration: const InputDecoration(labelText: 'Sesso'),
                  items: const [
                    DropdownMenuItem(
                      value: DogSex.male,
                      child: Text('Maschio'),
                    ),
                    DropdownMenuItem(
                      value: DogSex.female,
                      child: Text('Femmina'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setLocalState(() => selectedSex = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;

                setState(() {
                  widget.dog.name = nameController.text.trim();
                  widget.dog.breed = breedController.text.trim().isEmpty
                      ? 'Non specificata'
                      : breedController.text.trim();
                  widget.dog.microchip = microchipController.text.trim();
                  widget.dog.roi = roiController.text.trim();
                  widget.dog.birthDate = parseDate(birthDateController.text);
                  widget.dog.sex = selectedSex;
                });

                await widget.onDataChanged();
                if (!mounted) return;
                Navigator.pop(dialogContext);
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> addMedicalEntry() async {
    final typeController = TextEditingController();
    final descController = TextEditingController();
    final dateController = TextEditingController(text: formatDate(DateTime.now()));
    final nextDueController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuova voce clinica'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: typeController,
                decoration: const InputDecoration(labelText: 'Tipo'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Descrizione'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: dateController,
                decoration:
                    const InputDecoration(labelText: 'Data (gg/mm/aaaa)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nextDueController,
                decoration: const InputDecoration(
                  labelText: 'Prossima scadenza (gg/mm/aaaa)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () async {
              if (typeController.text.trim().isEmpty) return;
              setState(() {
                widget.dog.medicalEntries.add(
                  MedicalEntry(
                    type: typeController.text.trim(),
                    description: descController.text.trim(),
                    date: parseDate(dateController.text) ?? DateTime.now(),
                    nextDue: parseDate(nextDueController.text),
                  ),
                );
              });
              await widget.onDataChanged();
              if (!mounted) return;
              Navigator.pop(dialogContext);
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  Future<void> editMedicalEntry(int index) async {
    final entry = widget.dog.medicalEntries[index];
    final typeController = TextEditingController(text: entry.type);
    final descController = TextEditingController(text: entry.description);
    final dateController = TextEditingController(text: formatDate(entry.date));
    final nextDueController =
        TextEditingController(text: formatDate(entry.nextDue));

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Modifica voce clinica'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: typeController,
                decoration: const InputDecoration(labelText: 'Tipo'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Descrizione'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: dateController,
                decoration:
                    const InputDecoration(labelText: 'Data (gg/mm/aaaa)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nextDueController,
                decoration: const InputDecoration(
                  labelText: 'Prossima scadenza (gg/mm/aaaa)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () async {
              if (typeController.text.trim().isEmpty) return;
              setState(() {
                widget.dog.medicalEntries[index] = MedicalEntry(
                  type: typeController.text.trim(),
                  description: descController.text.trim(),
                  date: parseDate(dateController.text) ?? DateTime.now(),
                  nextDue: parseDate(nextDueController.text),
                );
              });
              await widget.onDataChanged();
              if (!mounted) return;
              Navigator.pop(dialogContext);
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  Future<void> deleteMedicalEntry(int index) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Elimina voce clinica'),
        content: const Text('Vuoi eliminare questa voce?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              setState(() => widget.dog.medicalEntries.removeAt(index));
              await widget.onDataChanged();
              if (!mounted) return;
              Navigator.pop(dialogContext);
            },
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  Future<void> addExpense() async {
    final categoryController = TextEditingController();
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    final dateController = TextEditingController(text: formatDate(DateTime.now()));

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuova spesa'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Categoria'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Descrizione'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Importo'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: dateController,
                decoration:
                    const InputDecoration(labelText: 'Data (gg/mm/aaaa)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () async {
              final parsedAmount = double.tryParse(
                amountController.text.trim().replaceAll(',', '.'),
              );
              if (categoryController.text.trim().isEmpty || parsedAmount == null) {
                return;
              }

              setState(() {
                widget.dog.expenses.add(
                  ExpenseItem(
                    category: categoryController.text.trim(),
                    description: descriptionController.text.trim(),
                    amount: parsedAmount,
                    date: parseDate(dateController.text) ?? DateTime.now(),
                  ),
                );
              });

              await widget.onDataChanged();
              if (!mounted) return;
              Navigator.pop(dialogContext);
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  Future<void> editExpense(int index) async {
    final expense = widget.dog.expenses[index];
    final categoryController = TextEditingController(text: expense.category);
    final descriptionController =
        TextEditingController(text: expense.description);
    final amountController =
        TextEditingController(text: expense.amount.toStringAsFixed(2));
    final dateController = TextEditingController(text: formatDate(expense.date));

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Modifica spesa'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Categoria'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Descrizione'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Importo'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: dateController,
                decoration:
                    const InputDecoration(labelText: 'Data (gg/mm/aaaa)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () async {
              final parsedAmount = double.tryParse(
                amountController.text.trim().replaceAll(',', '.'),
              );
              if (categoryController.text.trim().isEmpty || parsedAmount == null) {
                return;
              }

              setState(() {
                widget.dog.expenses[index] = ExpenseItem(
                  category: categoryController.text.trim(),
                  description: descriptionController.text.trim(),
                  amount: parsedAmount,
                  date: parseDate(dateController.text) ?? DateTime.now(),
                );
              });

              await widget.onDataChanged();
              if (!mounted) return;
              Navigator.pop(dialogContext);
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  Future<void> deleteExpense(int index) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Elimina spesa'),
        content: const Text('Vuoi eliminare questa spesa?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              setState(() => widget.dog.expenses.removeAt(index));
              await widget.onDataChanged();
              if (!mounted) return;
              Navigator.pop(dialogContext);
            },
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  Future<void> addAttachmentFromPicker(String section) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Fotocamera'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final file = await _imagePicker.pickImage(
                  source: ImageSource.camera,
                );
                if (file == null) return;
                setState(() {
                  widget.dog.attachments.add(
                    AttachmentItem(
                      name: file.name,
                      type: 'IMG',
                      path: file.path,
                      section: section,
                    ),
                  );
                });
                await widget.onDataChanged();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galleria'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final file = await _imagePicker.pickImage(
                  source: ImageSource.gallery,
                );
                if (file == null) return;
                setState(() {
                  widget.dog.attachments.add(
                    AttachmentItem(
                      name: file.name,
                      type: 'IMG',
                      path: file.path,
                      section: section,
                    ),
                  );
                });
                await widget.onDataChanged();
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('File del dispositivo'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final result = await FilePicker.pickFiles();
                if (result == null || result.files.isEmpty) return;
                final file = result.files.first;
                setState(() {
                  widget.dog.attachments.add(
                    AttachmentItem(
                      name: file.name,
                      type: file.extension?.toUpperCase() ?? 'FILE',
                      path: file.path ?? '',
                      section: section,
                    ),
                  );
                });
                await widget.onDataChanged();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> deleteAttachment(AttachmentItem item) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Elimina allegato'),
        content: Text('Vuoi eliminare ${item.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              setState(() => widget.dog.attachments.remove(item));
              await widget.onDataChanged();
              if (!mounted) return;
              Navigator.pop(dialogContext);
            },
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  Future<void> editGenealogy() async {
    final g = widget.dog.genealogy;

    final sireController = TextEditingController(text: g.sire);
    final damController = TextEditingController(text: g.dam);
    final pgfController = TextEditingController(text: g.paternalGrandfather);
    final pgmController = TextEditingController(text: g.paternalGrandmother);
    final mgfController = TextEditingController(text: g.maternalGrandfather);
    final mgmController = TextEditingController(text: g.maternalGrandmother);
    final greatControllers =
        g.greatGrandparents.map((e) => TextEditingController(text: e)).toList();
    final greatGreatControllers = g.greatGreatGrandparents
        .map((e) => TextEditingController(text: e))
        .toList();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Genealogia completa'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: sireController,
                  decoration: const InputDecoration(labelText: 'Padre'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: damController,
                  decoration: const InputDecoration(labelText: 'Madre'),
                ),
                const SizedBox(height: 18),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Nonni',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pgfController,
                  decoration: const InputDecoration(labelText: 'Nonno paterno'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pgmController,
                  decoration: const InputDecoration(labelText: 'Nonna paterna'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: mgfController,
                  decoration: const InputDecoration(labelText: 'Nonno materno'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: mgmController,
                  decoration: const InputDecoration(labelText: 'Nonna materna'),
                ),
                const SizedBox(height: 18),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Bisnonni',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                ...List.generate(
                  8,
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: greatControllers[i],
                      decoration: InputDecoration(
                        labelText: 'Bisnonno/Bisnonna ${i + 1}',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Trisnonni',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                ...List.generate(
                  16,
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: greatGreatControllers[i],
                      decoration: InputDecoration(
                        labelText: 'Trisnonno/Trisnonna ${i + 1}',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () async {
              setState(() {
                g.sire = sireController.text.trim();
                g.dam = damController.text.trim();
                g.paternalGrandfather = pgfController.text.trim();
                g.paternalGrandmother = pgmController.text.trim();
                g.maternalGrandfather = mgfController.text.trim();
                g.maternalGrandmother = mgmController.text.trim();
                g.greatGrandparents = greatControllers
                    .map((controller) => controller.text.trim())
                    .toList();
                g.greatGreatGrandparents = greatGreatControllers
                    .map((controller) => controller.text.trim())
                    .toList();
              });
              await widget.onDataChanged();
              if (!mounted) return;
              Navigator.pop(dialogContext);
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  Future<void> addPedigreePhoto() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Fotografa pedigree'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final file = await _imagePicker.pickImage(
                  source: ImageSource.camera,
                );
                if (file == null) return;
                setState(() {
                  widget.dog.genealogy.pedigreeAttachments.add(file.name);
                });
                await widget.onDataChanged();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galleria'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final file = await _imagePicker.pickImage(
                  source: ImageSource.gallery,
                );
                if (file == null) return;
                setState(() {
                  widget.dog.genealogy.pedigreeAttachments.add(file.name);
                });
                await widget.onDataChanged();
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('File del dispositivo'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final result = await FilePicker.pickFiles();
                if (result == null || result.files.isEmpty) return;
                final file = result.files.first;
                setState(() {
                  widget.dog.genealogy.pedigreeAttachments.add(file.name);
                });
                await widget.onDataChanged();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> deletePedigreeAttachment(String name) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Elimina foto pedigree'),
        content: Text('Vuoi eliminare $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              setState(() {
                widget.dog.genealogy.pedigreeAttachments.remove(name);
              });
              await widget.onDataChanged();
              if (!mounted) return;
              Navigator.pop(dialogContext);
            },
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  Future<void> addLitter() async {
    final litterController = TextEditingController();
    final lastHeatController =
        TextEditingController(text: formatDate(widget.dog.lastHeatDate));
    final nextHeatController =
        TextEditingController(text: formatDate(widget.dog.nextEstimatedHeatDate));

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Riproduzione'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: litterController,
                decoration: const InputDecoration(labelText: 'Cucciolata / nota'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: lastHeatController,
                decoration:
                    const InputDecoration(labelText: 'Ultimo calore (gg/mm/aaaa)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nextHeatController,
                decoration: const InputDecoration(
                  labelText: 'Prossimo calore stimato (gg/mm/aaaa)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () async {
              setState(() {
                widget.dog.lastHeatDate = parseDate(lastHeatController.text);
                widget.dog.nextEstimatedHeatDate =
                    parseDate(nextHeatController.text);
                if (litterController.text.trim().isNotEmpty) {
                  widget.dog.litters.add(litterController.text.trim());
                }
              });
              await widget.onDataChanged();
              if (!mounted) return;
              Navigator.pop(dialogContext);
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  Future<void> importVisiblePedigreeFromCurrentPage() async {
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Import automatico ENCI disponibile su Android con WebView interna.',
          ),
        ),
      );
      return;
    }

    final result = await Navigator.push<List<Map<String, dynamic>>>(
      context,
      MaterialPageRoute(
        builder: (_) => EnciPortalPage(
          roi: widget.dog.roi,
          microchip: widget.dog.microchip,
          importMode: true,
        ),
      ),
    );

    if (result == null || result.isEmpty) return;

    final nodes = result.map((item) {
      final roleKey = item['roleKey']?.toString() ?? '';
      return PedigreeNode(
        code: item['code']?.toString() ?? '',
        name: item['name']?.toString() ?? '',
        sex: item['sex']?.toString() ?? '',
        generation: generationFromRole(roleKey),
        roleKey: roleKey,
      );
    }).toList();

    final g = widget.dog.genealogy;

    setState(() {
      widget.dog.pedigreeNodes = nodes;

      final byRole = <String, PedigreeNode>{
        for (final n in nodes) n.roleKey: n,
      };

      g.sire = byRole['sire']?.name ?? g.sire;
      g.dam = byRole['dam']?.name ?? g.dam;
      g.paternalGrandfather = byRole['pgf']?.name ?? g.paternalGrandfather;
      g.paternalGrandmother = byRole['pgm']?.name ?? g.paternalGrandmother;
      g.maternalGrandfather = byRole['mgf']?.name ?? g.maternalGrandfather;
      g.maternalGrandmother = byRole['mgm']?.name ?? g.maternalGrandmother;

      for (int i = 0; i < 8; i++) {
        final key = 'g${i + 1}';
        if (byRole[key] != null) {
          g.greatGrandparents[i] = byRole[key]!.name;
        }
      }

      for (int i = 0; i < 16; i++) {
        final key = 'g${i + 9}';
        if (byRole[key] != null) {
          g.greatGreatGrandparents[i] = byRole[key]!.name;
        }
      }

      final selfNode = byRole['self'];
      if (selfNode != null) {
        if (selfNode.code.isNotEmpty) widget.dog.roi = selfNode.code;
        if (selfNode.name.isNotEmpty) widget.dog.name = selfNode.name;
      }

      final inb = calculateInbreedingFromVisiblePedigree(nodes);
      widget.dog.inbreedingCoefficient = inb.coefficient;
    });

    await widget.onDataChanged();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Pedigree importato. Coefficiente stimato: ${widget.dog.inbreedingCoefficient.toStringAsFixed(2)}%',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dog = widget.dog;
    final g = dog.genealogy;

    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: Text(dog.name),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Anagrafica'),
              Tab(text: 'Clinica'),
              Tab(text: 'Allegati'),
              Tab(text: 'Genealogia'),
              Tab(text: 'Accoppiamenti'),
              Tab(text: 'Riproduzione'),
              Tab(text: 'Spese'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FilledButton.icon(
                  onPressed: editAnagrafica,
                  icon: const Icon(Icons.edit),
                  label: const Text('Modifica anagrafica'),
                ),
                const SizedBox(height: 12),
                _InfoRow(label: 'ID QR', value: dog.id),
                _InfoRow(label: 'Nome', value: dog.name),
                _InfoRow(label: 'Razza', value: dog.breed),
                _InfoRow(
                  label: 'Microchip',
                  value: dog.microchip.isEmpty ? '-' : dog.microchip,
                ),
                _InfoRow(
                  label: 'ROI / RSR',
                  value: dog.roi.isEmpty ? '-' : dog.roi,
                ),
                _InfoRow(label: 'Sesso', value: sexLabel(dog.sex)),
                _InfoRow(
                  label: 'Data di nascita',
                  value: dog.birthDate == null ? '-' : formatDate(dog.birthDate),
                ),
                _InfoRow(
                  label: 'Stato sanitario',
                  value: healthText(widget.status),
                ),
                _InfoRow(
                  label: 'Totale spese cane',
                  value: '€ ${formatMoney(totalExpenses)}',
                ),
                _InfoRow(
                  label: 'Coeff. consanguinità stimato',
                  value: '${dog.inbreedingCoefficient.toStringAsFixed(2)}%',
                ),
                const SizedBox(height: 12),
                Center(
                  child: QrImageView(
                    data: dog.id,
                    version: QrVersions.auto,
                    size: 180,
                    backgroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FilledButton.icon(
                  onPressed: addMedicalEntry,
                  icon: const Icon(Icons.add),
                  label: const Text('Aggiungi voce clinica'),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => addAttachmentFromPicker('Clinica'),
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Allega file clinico'),
                ),
                const SizedBox(height: 12),
                if (dog.medicalEntries.isEmpty)
                  const Text('Nessuna voce clinica inserita')
                else
                  ...List.generate(
                    dog.medicalEntries.length,
                    (index) {
                      final entry = dog.medicalEntries[index];
                      return Card(
                        child: ListTile(
                          title: Text('${entry.type} - ${entry.description}'),
                          subtitle: Text(
                            'Data: ${formatDate(entry.date)}\nProssima scadenza: ${formatDate(entry.nextDue)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => editMedicalEntry(index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => deleteMedicalEntry(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 12),
                ...sectionAttachments('Clinica').map(
                  (a) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.attach_file),
                      title: Text(a.name),
                      subtitle: Text(a.type),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => deleteAttachment(a),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FilledButton.icon(
                  onPressed: () => addAttachmentFromPicker('Allegati'),
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Aggiungi allegato'),
                ),
                const SizedBox(height: 12),
                if (sectionAttachments('Allegati').isEmpty)
                  const Text('Nessun allegato inserito')
                else
                  ...sectionAttachments('Allegati').map(
                    (a) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.attach_file),
                        title: Text(a.name),
                        subtitle: Text(a.type),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => deleteAttachment(a),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FilledButton.icon(
                  onPressed: editGenealogy,
                  icon: const Icon(Icons.edit),
                  label: const Text('Modifica pedigree'),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: importVisiblePedigreeFromCurrentPage,
                  icon: const Icon(Icons.download),
                  label: const Text('Importa pedigree visibile'),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: addPedigreePhoto,
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Aggiungi foto/documento pedigree'),
                ),
                const SizedBox(height: 12),
                _InfoRow(label: 'Padre', value: g.sire.isEmpty ? '-' : g.sire),
                _InfoRow(label: 'Madre', value: g.dam.isEmpty ? '-' : g.dam),
                _InfoRow(
                  label: 'Nonno paterno',
                  value: g.paternalGrandfather.isEmpty
                      ? '-'
                      : g.paternalGrandfather,
                ),
                _InfoRow(
                  label: 'Nonna paterna',
                  value: g.paternalGrandmother.isEmpty
                      ? '-'
                      : g.paternalGrandmother,
                ),
                _InfoRow(
                  label: 'Nonno materno',
                  value: g.maternalGrandfather.isEmpty
                      ? '-'
                      : g.maternalGrandfather,
                ),
                _InfoRow(
                  label: 'Nonna materna',
                  value: g.maternalGrandmother.isEmpty
                      ? '-'
                      : g.maternalGrandmother,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Bisnonni',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...List.generate(
                  8,
                  (i) => _InfoRow(
                    label: 'Bisnonno/Bisnonna ${i + 1}',
                    value: g.greatGrandparents[i].isEmpty
                        ? '-'
                        : g.greatGrandparents[i],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Trisnonni',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...List.generate(
                  16,
                  (i) => _InfoRow(
                    label: 'Trisnonno/Trisnonna ${i + 1}',
                    value: g.greatGreatGrandparents[i].isEmpty
                        ? '-'
                        : g.greatGreatGrandparents[i],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Pedigree importato',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (dog.pedigreeNodes.isEmpty)
                  const Text('Nessun pedigree importato')
                else
                  ...dog.pedigreeNodes.map(
                    (n) => Card(
                      child: ListTile(
                        title: Text('${n.code} - ${n.name}'),
                        subtitle: Text(
                          '${roleLabel(n.roleKey)} • Generazione ${n.generation} • ${n.sex}',
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                if (g.pedigreeAttachments.isNotEmpty)
                  ...g.pedigreeAttachments.map(
                    (name) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.image),
                        title: Text(name),
                        subtitle: const Text('Foto documento pedigree'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => deletePedigreeAttachment(name),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                Card(
                  child: ListTile(
                    title: Text('Accoppiamenti'),
                    subtitle: Text(
                      'Qui aggiungeremo il calcolo consanguineità più preciso e gli accoppiamenti consigliati.',
                    ),
                  ),
                ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (dog.sex == DogSex.female)
                  FilledButton.icon(
                    onPressed: addLitter,
                    icon: const Icon(Icons.add),
                    label: const Text('Gestisci riproduzione'),
                  ),
                const SizedBox(height: 12),
                if (dog.sex == DogSex.female) ...[
                  _InfoRow(
                    label: 'Ultimo calore',
                    value: formatDate(dog.lastHeatDate),
                  ),
                  _InfoRow(
                    label: 'Prossimo calore stimato',
                    value: formatDate(dog.nextEstimatedHeatDate),
                  ),
                  if (dog.litters.isEmpty)
                    const Text('Nessuna cucciolata registrata')
                  else
                    ...dog.litters.map(
                      (litter) => Card(child: ListTile(title: Text(litter))),
                    ),
                ] else
                  const Text(
                    'Sezione riproduzione disponibile soprattutto per le fattrici.',
                  ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    title: const Text('Totale spese cane'),
                    subtitle: Text('€ ${formatMoney(totalExpenses)}'),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: addExpense,
                  icon: const Icon(Icons.add),
                  label: const Text('Aggiungi spesa'),
                ),
                const SizedBox(height: 12),
                if (dog.expenses.isEmpty)
                  const Text('Nessuna spesa inserita')
                else
                  ...List.generate(
                    dog.expenses.length,
                    (index) {
                      final expense = dog.expenses[index];
                      return Card(
                        child: ListTile(
                          title: Text(
                            '${expense.category} - € ${formatMoney(expense.amount)}',
                          ),
                          subtitle: Text(
                            '${expense.description}\nData: ${formatDate(expense.date)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => editExpense(index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => deleteExpense(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class EnciPortalPage extends StatefulWidget {
  final String roi;
  final String microchip;
  final bool importMode;

  const EnciPortalPage({
    super.key,
    required this.roi,
    required this.microchip,
    this.importMode = false,
  });

  @override
  State<EnciPortalPage> createState() => _EnciPortalPageState();
}

class _EnciPortalPageState extends State<EnciPortalPage> {
  late final WebViewController controller;
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    searchController.text =
        widget.roi.isNotEmpty ? widget.roi : widget.microchip;

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url.toLowerCase();
            if (url.contains('.pdf') || url.contains('/pdf') || url.contains('download')) {
              _downloadAndOpenFile(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(
        Uri.parse(
          'https://www.enci.it/libro-genealogico/libro-genealogico-on-line',
        ),
      );
  }

  Future<void> _downloadAndOpenFile(String url) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Download in corso...')),
    );

    try {
      final dir = await getTemporaryDirectory();
      final fileName = url.split('/').last.split('?').first;
      final savePath = '${dir.path}/${fileName.isNotEmpty ? fileName : 'pedigree.pdf'}';

      await Dio().download(url, savePath);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File scaricato. Apertura...')),
      );

      final result = await OpenFile.open(savePath);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossibile aprire il file: ${result.message}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante il download: $e')),
      );
    }
  }

  Future<void> fillSearchField() async {
  final value = searchController.text.trim();
  if (value.isEmpty) return;
  final escaped = value.replaceAll("'", "\\'");

  await controller.runJavaScript(r"""
    (function(value) {
      const chip = document.querySelector('#chip');
      const loi = document.querySelector('#loi');
      const nameField = document.querySelector('#sogg');

      function setNativeValue(element, newValue) {
        const valueSetter =
          Object.getOwnPropertyDescriptor(element.__proto__, 'value')?.set;
        valueSetter?.call(element, newValue);
        element.dispatchEvent(new Event('input', { bubbles: true }));
        element.dispatchEvent(new Event('change', { bubbles: true }));
        element.dispatchEvent(new Event('blur', { bubbles: true }));
      }

      const upper = value.toUpperCase();
      const looksLikeCode =
        /^(LO|LI|LA)[A-Z0-9\/-]+$/i.test(upper) ||
        /^[A-Z]{2}\d{2,}\/?\d*$/i.test(upper);

      if (nameField) {
        setNativeValue(nameField, '');
      }

      if (looksLikeCode) {
        if (loi) setNativeValue(loi, upper);
        if (chip) setNativeValue(chip, '');
      } else {
        if (chip) setNativeValue(chip, value);
        if (loi) setNativeValue(loi, '');
      }
    })('VALUE_TO_REPLACE');
  """.replaceFirst('VALUE_TO_REPLACE', escaped));
}
    
  Future<void> clickSearch() async {
    await controller.runJavaScript("""
      (function() {
        const btn = document.querySelector('#BtnDefault');
        if (btn) btn.click();
      })();
    """);
  }

  Future<void> importVisiblePedigree() async {
  final raw = await controller.runJavaScriptReturningResult(r"""
    (function() {
      function txt(el, selector) {
        const n = el.querySelector(selector);
        return n ? n.innerText.trim() : '';
      }

      function roleFromNumber(num) {
        if (num === 1) return 'sire';
        if (num === 2) return 'dam';
        if (num === 3) return 'pgf';
        if (num === 4) return 'pgm';
        if (num === 5) return 'mgf';
        if (num === 6) return 'mgm';
        return 'g' + (num - 6);
      }

      const result = [];
      const debug = {
        detailFound: false,
        pedigreeFound: false,
        rowCount: 0,
        cellCount: 0,
      };

      const detailRoot =
        document.querySelector('#Dettaglio') ||
        document.querySelector('.print-ana');

      if (detailRoot) {
        debug.detailFound = true;
      }

      const selfNode =
        document.querySelector('#Dettaglio .nome .pull-left') ||
        document.querySelector('.print-ana .nome .pull-left') ||
        document.querySelector('.print-ana .nome');

      const maleNode =
        document.querySelector('#Dettaglio .sesso.mars') ||
        document.querySelector('.print-ana .sesso.mars');

      const femaleNode =
        document.querySelector('#Dettaglio .sesso.venus') ||
        document.querySelector('.print-ana .sesso.venus');

      if (selfNode) {
        const text = selfNode.innerText.trim();
        const parts = text.split(' - ');
        result.push({
          roleKey: 'self',
          code: parts.length > 1 ? parts[0].trim() : '',
          name: parts.length > 1 ? parts.slice(1).join(' - ').trim() : text,
          sex: maleNode ? 'M' : (femaleNode ? 'F' : '')
        });
      }

      const pedigreeRoot =
        document.querySelector('#PedigreeCard') ||
        document.querySelector('.card.pedigree') ||
        document.querySelector('.pedigree');

      if (pedigreeRoot) {
        debug.pedigreeFound = true;
      }

      const pedigreeRows = pedigreeRoot
        ? pedigreeRoot.querySelectorAll('.row')
        : [];

      const pedigreeCells = pedigreeRoot
        ? pedigreeRoot.querySelectorAll('.cella')
        : [];

      debug.rowCount = pedigreeRows.length;
      debug.cellCount = pedigreeCells.length;

      pedigreeRows.forEach((row) => {
        const cell = row.querySelector('.cella');
        if (!cell) return;

        const classList = Array.from(row.classList);
        let pedigreeClass = null;

        for (const cls of classList) {
          if (/^[pm]\d{2}$/.test(cls)) {
            pedigreeClass = cls;
            break;
          }
        }

        if (!pedigreeClass) return;

        const num = parseInt(pedigreeClass.substring(1), 10);
        if (!num || num < 1) return;

        const sex = pedigreeClass.startsWith('p') ? 'M' : 'F';
        const code = txt(cell, '.codice');
        const name = txt(cell, '.nome');

        if (!code && !name) return;

        result.push({
          roleKey: roleFromNumber(num),
          code: code,
          name: name,
          sex: sex
        });
      });

      return JSON.stringify({
        debug: debug,
        items: result
      });
    })();
  """);

  final text = raw.toString();
  final cleaned = text.startsWith('"') ? jsonDecode(text) : text;
  final decoded = Map<String, dynamic>.from(jsonDecode(cleaned) as Map);

  final debug = Map<String, dynamic>.from(decoded['debug'] as Map? ?? {});
  final items = (decoded['items'] as List<dynamic>? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .where((e) =>
          (e['code']?.toString().trim().isNotEmpty ?? false) ||
          (e['name']?.toString().trim().isNotEmpty ?? false))
      .toList();

  if (!mounted) return;

  if (items.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Nessun dato trovato. detail=${debug['detailFound']}, pedigree=${debug['pedigreeFound']}, righe=${debug['rowCount']}, celle=${debug['cellCount']}',
        ),
      ),
    );
    return;
  }

  Navigator.pop(context, items);
}

 @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portale ENCI'),
        actions: [
          if (widget.importMode)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Importa pedigree visibile',
              onPressed: importVisiblePedigree,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    labelText: 'ROI / Microchip',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: fillSearchField,
                      icon: const Icon(Icons.edit),
                      label: const Text('Compila ricerca'),
                    ),
                    FilledButton.icon(
                      onPressed: clickSearch,
                      icon: const Icon(Icons.search),
                      label: const Text('Cerca'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        controller.loadRequest(
                          Uri.parse(
                            'https://www.enci.it/libro-genealogico/libro-genealogico-on-line',
                          ),
                        );
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Riapri ENCI'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: WebViewWidget(controller: controller),
          ),
        ],
      ),
    );
  }
}

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  bool found = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scansiona QR'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (found) return;
              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;

              final code = barcodes.first.rawValue;
              if (code == null || code.isEmpty) return;

              found = true;
              Navigator.pop(context, code);
            },
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label),
        subtitle: Text(value),
      ),
    );
  }
}

extension _FirstOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}