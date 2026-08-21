import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateInfo {
  final String version;
  final int buildNumber;
  final String changelog;
  final String apkUrl;

  const UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.changelog,
    required this.apkUrl,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] as String? ?? '0.0.0',
      buildNumber: json['build_number'] as int? ?? 0,
      changelog: json['changelog'] as String? ?? '',
      apkUrl: json['apk_url'] as String? ?? '',
    );
  }
}

class UpdateService {
  static final UpdateService _instance = UpdateService._();
  static UpdateService get shared => _instance;
  UpdateService._();

  static const String _versionUrl =
      'https://jc0o0b.github.io/NaviMot-GO/version.json';

  Future<UpdateInfo?> checkForUpdate() async {
    if (kIsWeb) return null;
    try {
      final response = await http
          .get(Uri.parse(_versionUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final remote = UpdateInfo.fromJson(data);
      final local = await PackageInfo.fromPlatform();
      final localBuild = int.tryParse(local.buildNumber) ?? 0;
      if (remote.buildNumber > localBuild) return remote;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> openUpdate(UpdateInfo info) async {
    final uri = Uri.parse(info.apkUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
