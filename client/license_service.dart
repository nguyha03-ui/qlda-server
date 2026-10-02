// QLDA Work Manager - kiểm tra license + cập nhật (Flutter: Windows / Android / iOS / Web)
// pubspec.yaml cần: http, crypto, shared_preferences
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _base = 'https://nguyha03-ui.github.io/qlda-server';
const _cacheKey = 'qlda_license_cache';
const _offlineGraceDays = 7;

class LicenseResult {
  final bool ok;
  final String code; // active | blocked | unpaid | expired | unknown | offline
  final String message;
  final bool offline;
  const LicenseResult(this.ok, this.code, this.message, {this.offline = false});
}

class UpdateInfo {
  final bool hasUpdate, forced;
  final String latest, url, notes;
  const UpdateInfo(this.hasUpdate, this.forced, this.latest, this.url, this.notes);
}

/// Băm giống hệt gen_license.py: SHA-256("mãKH:KEY", KEY viết hoa, bỏ khoảng trắng)
String licenseHash(String customerCode, String licenseKey) {
  final raw = '${customerCode.trim()}:${licenseKey.trim().toUpperCase()}';
  return sha256.convert(utf8.encode(raw)).toString();
}

Future<Map<String, dynamic>> _fetchJson(String file) async {
  final uri = Uri.parse('$_base/$file?t=${DateTime.now().millisecondsSinceEpoch}');
  final r = await http.get(uri).timeout(const Duration(seconds: 10));
  if (r.statusCode != 200) throw Exception('$file: HTTP ${r.statusCode}');
  return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
}

LicenseResult _judge(Map<String, dynamic>? e, {bool offline = false}) {
  if (e == null) return const LicenseResult(false, 'unknown', 'Mã khách hàng hoặc license key không đúng.');
  if (e['status'] == 'blocked') {
    return const LicenseResult(false, 'blocked', 'License đã bị khóa. Liên hệ Mr Hà: 0916269395.');
  }
  if (e['status'] == 'unpaid') return const LicenseResult(false, 'unpaid', 'License chưa được thanh toán.');
  final exp = e['expires'] as String?;
  if (exp != null && DateTime.parse('${exp}T23:59:59').isBefore(DateTime.now())) {
    return LicenseResult(false, 'expired', 'License đã hết hạn ngày $exp.');
  }
  return LicenseResult(true, 'active', exp != null ? 'Còn hạn đến $exp' : 'License vĩnh viễn', offline: offline);
}

/// Gọi khi mở ứng dụng và định kỳ (vd. mỗi 6 giờ).
Future<LicenseResult> checkLicense(String customerCode, String licenseKey) async {
  final h = licenseHash(customerCode, licenseKey);
  final prefs = await SharedPreferences.getInstance();
  try {
    final db = await _fetchJson('license-status.json');
    final entry = (db['licenses'] as Map<String, dynamic>?)?[h] as Map<String, dynamic>?;
    if (entry != null) {
      await prefs.setString(_cacheKey, jsonEncode({'h': h, 'entry': entry, 'at': DateTime.now().millisecondsSinceEpoch}));
    }
    return _judge(entry);
  } catch (_) {
    // Mất mạng: dùng bản lưu gần nhất trong 7 ngày
    final raw = prefs.getString(_cacheKey);
    if (raw != null) {
      final c = jsonDecode(raw) as Map<String, dynamic>;
      final age = DateTime.now().millisecondsSinceEpoch - (c['at'] as int);
      if (c['h'] == h && age < _offlineGraceDays * 86400000) {
        return _judge(c['entry'] as Map<String, dynamic>, offline: true);
      }
    }
    return const LicenseResult(false, 'offline', 'Không kết nối được máy chủ license. Hãy kiểm tra mạng.');
  }
}

int _cmp(String a, String b) {
  final x = a.split('.').map(int.parse).toList(), y = b.split('.').map(int.parse).toList();
  for (var i = 0; i < 3; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d;
  }
  return 0;
}

Future<UpdateInfo> checkUpdate(String currentVersion) async {
  final v = await _fetchJson('version.json');
  return UpdateInfo(
    _cmp(currentVersion, v['latest_version']) < 0,
    _cmp(currentVersion, v['min_supported_version']) < 0, // bản quá cũ → bắt buộc cập nhật
    v['latest_version'], v['download_url'] ?? '', v['release_notes'] ?? '',
  );
}
