import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/home_sheet.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ustawienia')),
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
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'NaviMot GO 1.0',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
