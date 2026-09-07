import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/emergency_contact.dart';

class EmergencyContactStorage {
  static const _key = 'emergency_contacts';

  Future<List<EmergencyContact>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((e) => EmergencyContact.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  Future<List<EmergencyContact>> getSosContacts() async {
    final all = await getAll();
    final sos = all.where((c) => c.isSos).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    return sos;
  }

  Future<void> saveAll(List<EmergencyContact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      contacts.map((c) => jsonEncode(c.toJson())).toList(),
    );
  }

  Future<void> add(EmergencyContact contact) async {
    final list = await getAll();
    list.add(contact);
    await saveAll(list);
  }

  Future<void> remove(String id) async {
    final list = await getAll();
    list.removeWhere((c) => c.id == id);
    await _normalizeSosPriorities(list);
    await saveAll(list);
  }

  Future<void> reorderSos(List<EmergencyContact> orderedSos) async {
    final all = await getAll();
    final nonSos = all.where((c) => !c.isSos).toList();
    final reordered = <EmergencyContact>[];
    for (var i = 0; i < orderedSos.length; i++) {
      reordered.add(orderedSos[i].copyWith(priority: i + 1));
    }
    await saveAll([...nonSos, ...reordered]);
  }

  Future<void> _normalizeSosPriorities(List<EmergencyContact> all) async {
    final sos = all.where((c) => c.isSos).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    for (var i = 0; i < sos.length; i++) {
      final idx = all.indexWhere((c) => c.id == sos[i].id);
      if (idx >= 0) {
        all[idx] = all[idx].copyWith(priority: i + 1);
      }
    }
  }

  Future<int> nextSosPriority() async {
    final sos = await getSosContacts();
    if (sos.isEmpty) return 1;
    return sos.map((c) => c.priority).reduce((a, b) => a > b ? a : b) + 1;
  }
}
