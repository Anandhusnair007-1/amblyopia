import 'dart:convert';
import 'package:encrypt/encrypt.dart';

class EncryptionUtil {
  static String _normalizeKey(String key) {
    if (key.length >= 32) return key.substring(0, 32);
    return key.padRight(32, '0');
  }

  static String encryptText(String plainText, String key) {
    final normalizedKey = Key.fromUtf8(_normalizeKey(key));
    final iv = IV.fromLength(16);
    final encrypter = Encrypter(AES(normalizedKey, mode: AESMode.cbc));
    return encrypter.encrypt(plainText, iv: iv).base64;
  }

  static String decryptText(String cipherText, String key) {
    final normalizedKey = Key.fromUtf8(_normalizeKey(key));
    final iv = IV.fromLength(16);
    final encrypter = Encrypter(AES(normalizedKey, mode: AESMode.cbc));
    return encrypter.decrypt(Encrypted.fromBase64(cipherText), iv: iv);
  }

  static String encodeBase64(Map<String, dynamic> data) => base64Encode(utf8.encode(jsonEncode(data)));
}
