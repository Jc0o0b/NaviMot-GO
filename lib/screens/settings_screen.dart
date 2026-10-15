import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/update_service.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onBackToMap;
  const SettingsScreen({super.key, this.onBackToMap});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _checkingUpdate = false;
  UpdateInfo? _updateInfo;
  String _currentVersion = '';
  Timer? _nicknameDebounce;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  @override
  void dispose() {
    _nicknameDebounce?.cancel();
    super.dispose();
  }

  void _onNicknameChanged(String value) {
    _nicknameDebounce?.cancel();
    _nicknameDebounce = Timer(const Duration(milliseconds: 600), () {
      if (mounted) context.read<SettingsProvider>().setNickname(value);
    });
  }

  Future<void> _loadVersion() async {
    if (kIsWeb) return;
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _currentVersion = '${info.version}+${info.buildNumber}');
      }
    } catch (_) {}
  }

  Future<void> _checkUpdate() async {
    setState(() {
      _checkingUpdate = true;
      _updateInfo = null;
    });
    final info = await UpdateService.shared.checkForUpdate();
    if (!mounted) return;
    setState(() {
      _checkingUpdate = false;
      _updateInfo = info;
    });
    if (info == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masz najnowszą wersję aplikacji')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ustawienia'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Wróć do mapy',
          onPressed: () {
            Navigator.of(context).pop();
            widget.onBackToMap?.call();
          },
        ),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          final scheme = Theme.of(context).colorScheme;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _SectionLabel('Wygląd'),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary:
                          Icon(Icons.dark_mode_outlined, color: scheme.primary),
                      title: const Text('Tryb ciemny (Dark Mode)',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle:
                          const Text('Ciemny motyw ułatwia czytanie w nocy'),
                      value: settings.darkMode,
                      onChanged: (v) => settings.setDarkMode(v),
                    ),
                    const Divider(height: 1, indent: 56),
                    SwitchListTile(
                      secondary:
                          Icon(Icons.wb_sunny_outlined, color: scheme.primary),
                      title: const Text('Tryb słońca (wysoki kontrast)',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text(
                          'Wyraźny interfejs czytelny w pełnym słońcu'),
                      value: settings.highContrast,
                      onChanged: (v) => settings.setHighContrast(v),
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildAccentPicker(settings),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const _SectionLabel('Nawigacja i dźwięk'),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary:
                          Icon(Icons.volume_up_outlined, color: scheme.primary),
                      title: const Text('Dźwięk',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Włącz dźwięk w aplikacji'),
                      value: settings.audioEnabled,
                      onChanged: (v) => settings.setAudioEnabled(v),
                    ),
                    const Divider(height: 1, indent: 56),
                    SwitchListTile(
                      secondary: Icon(Icons.record_voice_over_outlined,
                          color: scheme.primary),
                      title: const Text('Komunikaty głosowe',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle:
                          const Text('Nawigacja odczytuje wskazówki na głos'),
                      value: settings.voiceCommands,
                      onChanged: settings.audioEnabled
                          ? (v) => settings.setVoiceCommands(v)
                          : null,
                    ),
                    const Divider(height: 1, indent: 56),
                    SwitchListTile(
                      secondary: Icon(Icons.screen_lock_portrait_outlined,
                          color: scheme.primary),
                      title: const Text('Nie wyłączaj ekranu',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text(
                          'Ekran pozostaje włączony podczas nawigacji'),
                      value: settings.keepScreenOn,
                      onChanged: (v) => settings.setKeepScreenOn(v),
                    ),
                    const Divider(height: 1, indent: 56),
                    SwitchListTile(
                      secondary:
                          Icon(Icons.format_size_outlined, color: scheme.primary),
                      title: const Text('Duże napisy nawigacji',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text(
                          'Powiększ wskazówki i prędkość na ekranie jazdy'),
                      value: settings.bigNavFont,
                      onChanged: (v) => settings.setBigNavFont(v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const _SectionLabel('Twój profil'),
              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.badge_outlined,
                              color: scheme.primary, size: 20),
                          const SizedBox(width: 8),
                          const Text('Pseudonim na czacie',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: settings.nickname,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          maxLength: 20,
                          buildCounter: (_, {required currentLength, maxLength, required isFocused}) =>
                              const SizedBox.shrink(),
                      onFieldSubmitted: (v) {
                        _nicknameDebounce?.cancel();
                        settings.setNickname(v);
                      },
                      onChanged: _onNicknameChanged,
                      ),
                    ],
                  ),
                ),
              ),
              if (!kIsWeb) ...[
                const SizedBox(height: 12),
                const _SectionLabel('Aktualizacja'),
                Card(
                  child: _buildUpdateSection(),
                ),
              ],
              const SizedBox(height: 12),
              const _SectionLabel('Informacje'),
              Card(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Icon(Icons.motorcycle, size: 48, color: scheme.primary),
                    const SizedBox(height: 8),
                    const Text('NaviMot GO',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    Text('Wersja $_currentVersion',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    ListTile(
                      leading:
                          Icon(Icons.info_outline, color: scheme.primary),
                      title: const Text('O aplikacji i twórcy',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text(
                          'Co potrafi NaviMot GO, z czego korzysta i kto za nim stoi'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showAbout(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUpdateSection() {
    if (_checkingUpdate) {
      return const ListTile(
        leading: CircularProgressIndicator(strokeWidth: 2),
        title: Text('Sprawdzam aktualizacje...'),
      );
    }
    if (_updateInfo != null) {
      return ListTile(
        leading: const Icon(Icons.system_update_alt, color: Colors.green),
        title: Text('Nowa wersja: ${_updateInfo!.version}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(_updateInfo!.changelog.isNotEmpty
            ? _updateInfo!.changelog
            : 'Kliknij, aby pobrać aktualizację'),
        trailing: const Icon(Icons.download, color: Colors.green),
        onTap: () => UpdateService.shared.openUpdate(_updateInfo!),
      );
    }
    return ListTile(
      leading:
          Icon(Icons.update, color: Theme.of(context).colorScheme.primary),
      title: const Text('Sprawdź aktualizacje',
          style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: const Text('Pobierz najnowszą wersję aplikacji'),
      trailing: const Icon(Icons.chevron_right),
      onTap: _checkUpdate,
    );
  }

  Widget _buildAccentPicker(SettingsProvider settings) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined, color: scheme.primary, size: 20),
              const SizedBox(width: 8),
              const Text('Kolor akcentu',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < SettingsProvider.accentColors.length; i++)
                _accentDot(
                  color: SettingsProvider.accentColors[i],
                  name: SettingsProvider.accentNames[i],
                  selected: settings.accentIndex == i,
                  outline: scheme.onSurface,
                  onTap: () => settings.setAccentIndex(i),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _accentDot({
    required Color color,
    required String name,
    required bool selected,
    required Color outline,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? outline : Colors.transparent,
              width: 3,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 22)
              : null,
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bodyTheme = Theme.of(context).textTheme;

    Widget sectionTitle(String text) => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 6),
          child: Text(text,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: scheme.primary)),
        );

    Widget bullet(String text) => Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Icon(Icons.check_circle,
                    size: 14, color: scheme.primary),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: bodyTheme.bodyMedium)),
            ],
          ),
        );

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.motorcycle,
                              size: 40, color: scheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('NaviMot GO',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800)),
                                Text('Wersja $_currentVersion',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Nawigacja i planer tras stworzony z myślą o motocyklistach. '
                        'Zamiast zawsze najszybciej — szuka dróg malowniczych: krętych, '
                        'z widokami i ciekawymi miejscami po drodze.',
                        style: bodyTheme.bodyMedium,
                      ),

                      sectionTitle('Co potrafi'),
                      bullet('Wyznaczanie tras motocyklowych — warianty malowniczy i najszybszy'),
                      bullet('Realne omijanie autostrad i dróg płatnych'),
                      bullet('Nawigacja głosowa z ostrzeżeniami o zdarzeniach na drodze'),
                      bullet('Fotoradary i ograniczenia prędkości na trasie'),
                      bullet('Pogoda na trasie i alerty o niebezpiecznych warunkach'),
                      bullet('Miejsca dla motocyklistów: punkty widokowe, przełęcze, stacje, serwisy'),
                      bullet('Zgłoszenia społeczności — wypadki, remonty, niebezpieczeństwa'),
                      bullet('Zapis tras, udostępnianie i eksport GPX'),
                      bullet('Przystanki po drodze i kolejność postojów'),
                      bullet('Tryb słońca (wysoki kontrast) i blokada ekranu podczas jazdy'),

                      sectionTitle('Z jakich danych korzysta'),
                      Text(
                        'Mapy i miejsca: OpenStreetMap (Overpass API). '
                        'Wyznaczanie tras: OSRM oraz Valhalla. '
                        'Wyszukiwanie adresów: Photon i Nominatim. '
                        'Pogoda: Open-Meteo. '
                        'Aktualizacje: repozytorium aplikacji.\n\n'
                        'Wszystkie usługi są otwarte i darmowe. Aplikacja nie wymaga '
                        'konta ani rejestracji, a dane o trasach i zgłoszeniach '
                        'przechowywane są lokalnie na Twoim urządzeniu.',
                        style: bodyTheme.bodyMedium,
                      ),

                      sectionTitle('Twórca'),
                      Text(
                         'NaviMot GO powstało z pasji do motocykli i programowania. '
                         'Celem jest jeżdżenie pięknymi drogami i dzielenie się nimi '
                         'z innymi motocyklistami.\n\n'
                         'Twórca: NaviMot GO. Pomysły, błędy i sugestie mile widziane '
                         'w repozytorium aplikacji.',
                        style: bodyTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Zamknij'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
      ),
    );
  }
}
