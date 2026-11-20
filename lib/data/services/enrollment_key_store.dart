import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/crypto/enrollment_crypto.dart';

/// Guarda y recupera el par de claves X25519 usado por el estudiante para una clase.
abstract class EnrollmentKeyStore {
  Future<EnrollmentKeyPair?> load(String courseId, String studentCode);

  Future<void> save(String courseId, String studentCode, EnrollmentKeyPair pair);
}

/// Guarda el par de claves en las preferencias del celular.
class PrefsEnrollmentKeyStore implements EnrollmentKeyStore {
  const PrefsEnrollmentKeyStore();

  static String storageKey(String courseId, String studentCode) =>
      'enrollment_keypair_v1_${courseId}_$studentCode';

  @override
  Future<EnrollmentKeyPair?> load(String courseId, String studentCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey(courseId, studentCode));
      if (raw == null || raw.trim().isEmpty) return null;
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;
      final privateHex = decoded['privateKeyHex'];
      final publicHex = decoded['publicKeyHex'];
      if (privateHex is String && publicHex is String && privateHex.isNotEmpty && publicHex.isNotEmpty) {
        return EnrollmentKeyPair(privateKeyHex: privateHex, publicKeyHex: publicHex);
      }
      return null;
    } catch (error) {
      debugPrint('No se pudo leer el par de claves de inscripción: $error');
      return null;
    }
  }

  @override
  Future<void> save(String courseId, String studentCode, EnrollmentKeyPair pair) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode(<String, String>{
        'privateKeyHex': pair.privateKeyHex,
        'publicKeyHex': pair.publicKeyHex,
      });
      await prefs.setString(storageKey(courseId, studentCode), payload);
    } catch (error) {
      debugPrint('No se pudo guardar el par de claves de inscripción: $error');
    }
  }
}

/// Para pruebas y simulaciones en memoria.
class MemoryEnrollmentKeyStore implements EnrollmentKeyStore {
  MemoryEnrollmentKeyStore({Map<String, EnrollmentKeyPair>? initialKeys})
      : _store = initialKeys != null ? Map<String, EnrollmentKeyPair>.from(initialKeys) : <String, EnrollmentKeyPair>{};

  final Map<String, EnrollmentKeyPair> _store;

  static String _key(String courseId, String studentCode) => '${courseId}_$studentCode';

  @override
  Future<EnrollmentKeyPair?> load(String courseId, String studentCode) async {
    return _store[_key(courseId, studentCode)];
  }

  @override
  Future<void> save(String courseId, String studentCode, EnrollmentKeyPair pair) async {
    _store[_key(courseId, studentCode)] = pair;
  }
}
