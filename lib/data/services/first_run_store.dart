import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Recuerda si la persona ya vio el recorrido de "Cómo funciona".
abstract class FirstRunStore {
  Future<bool> hasSeenTour();

  Future<void> markTourSeen();
}

/// Lo guarda en las preferencias del celular.
class PrefsFirstRunStore implements FirstRunStore {
  const PrefsFirstRunStore();

  static const String key = 'how_it_works_seen_v1';

  @override
  Future<bool> hasSeenTour() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? false;
    } catch (error) {
      // Si las preferencias fallan, no se le estorba a la persona con el
      // recorrido en cada apertura: sigue disponible en Ayuda.
      debugPrint('No se pudo leer si ya vio el recorrido: $error');
      return true;
    }
  }

  @override
  Future<void> markTourSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, true);
    } catch (error) {
      debugPrint('No se pudo guardar que ya vio el recorrido: $error');
    }
  }
}

/// Para pruebas.
class MemoryFirstRunStore implements FirstRunStore {
  MemoryFirstRunStore({this.seen = false});

  bool seen;

  @override
  Future<bool> hasSeenTour() async => seen;

  @override
  Future<void> markTourSeen() async => seen = true;
}
