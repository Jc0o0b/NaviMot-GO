import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/home_sheet.dart';

class SettingsScreen extends StatelessWidget {
  final VoidCallback? onBackToMap;
  const SettingsScreen({super.key, this.onBackToMap});

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
            onBackToMap?.call();
          },
        ),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined,
                      color: Colors.deepOrange),
                  title: const Text('Tryb ciemny (Dark Mode)',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text(
                      'Ciemny motyw ułatwia czytanie w nocy'),
                  value: settings.darkMode,
                  onChanged: (v) => settings.setDarkMode(v),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.volume_up_outlined,
                          color: Colors.deepOrange),
                      title: const Text('Dźwięk',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Włącz dźwięk w aplikacji'),
                      value: settings.audioEnabled,
                      onChanged: (v) => settings.setAudioEnabled(v),
                    ),
                    const Divider(height: 1, indent: 56),
                    SwitchListTile(
                      secondary: const Icon(Icons.record_voice_over_outlined,
                          color: Colors.deepOrange),
                      title: const Text('Komunikaty głosowe',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle:
                          const Text('Nawigacja odczytuje wskazówki na głos'),
                      value: settings.voiceCommands,
                      onChanged: settings.audioEnabled
                          ? (v) => settings.setVoiceCommands(v)
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.badge_outlined,
                              color: Colors.deepOrange, size: 20),
                          SizedBox(width: 8),
                          Text('Pseudonim na czacie',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: settings.nickname,
                        decoration: const InputDecoration(
                          hintText: 'Twój pseudonim',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onFieldSubmitted: (v) => settings.setNickname(v),
                        onChanged: (v) => settings.setNickname(v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading:
                      const Icon(Icons.home_outlined, color: Colors.deepOrange),
                  title: const Text('Adres domowy',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    settings.home?.name ?? 'Ustaw adres domowy',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showHomeSheet(context),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    const Icon(Icons.motorcycle,
                        size: 48, color: Colors.deepOrange),
                    const SizedBox(height: 8),
                    const Text('NaviMot GO',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    const Text('Wersja 1.0.0',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.info_outline,
                          color: Colors.deepOrange),
                      title: const Text('O aplikacji',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle:
                          const Text('Co potrafi NaviMot GO i jak z niego korzystać'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showAbout(context),
                    ),
                    const Divider(height: 1),
                    const ListTile(
                      leading: Icon(Icons.person_outline,
                          color: Colors.deepOrange),
                      title: Text('Twórca aplikacji',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Jc0o0b — pasjonat motocykli i programowania'),
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

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'NaviMot GO',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.motorcycle,
          size: 48, color: Colors.deepOrange),
      applicationLegalese:
          'Nawigacja i malownicze trasy motocyklowe z pogodą, miejscami dla motocyklisty, '
          'wspólnotą i zgłoszeniami od społeczności.\n\n'
          'Aplikacja została stworzona z myślą o motocyklistach, którzy lubią odkrywać '
          'piękne drogi i dzielić się nimi z innymi.\n\nAutor: Jc0o0b',
      children: const [
        SizedBox(height: 8),
        Text('NaviMot GO używa otwartych danych mapowych oraz usług wyznaczania tras.'),
      ],
    );
  }
}
