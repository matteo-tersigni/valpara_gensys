import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cane.dart';

class StorageService {
  static const key = "cani";

  Future<List<Cane>> getCani() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(key);
    if (data == null) return [];

    final list = jsonDecode(data) as List;
    return list.map((e) => Cane.fromJson(e)).toList();
  }

  Future<void> salvaCani(List<Cane> cani) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = jsonEncode(cani.map((e) => e.toJson()).toList());
    await prefs.setString(key, jsonData);
  }
}