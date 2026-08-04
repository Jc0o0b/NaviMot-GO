import 'package:flutter/material.dart';
import '../widgets/section_header.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';

class MoreScreen extends StatelessWidget {
  final VoidCallback? onBackToMap;
  const MoreScreen({super.key, this.onBackToMap});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const SectionHeader(title: 'Więcej', icon: Icons.menu),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.forum,
                          color: Colors.deepOrange, size: 22),
                    ),
                    title: const Text('Czat',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Czat motocyklistów'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ChatScreen()),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.settings,
                          color: Colors.deepOrange, size: 22),
                    ),
                    title: const Text('Ustawienia',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Motyw, adres domowy, pseudonim'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) =>
                              SettingsScreen(onBackToMap: onBackToMap)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
