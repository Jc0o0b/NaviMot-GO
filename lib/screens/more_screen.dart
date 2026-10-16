import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/account_provider.dart';
import '../widgets/section_header.dart';
import 'account_screen.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';

class MoreScreen extends StatelessWidget {
  final VoidCallback? onBackToMap;
  const MoreScreen({super.key, this.onBackToMap});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountProvider>();
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
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                          account.isSignedIn
                              ? Icons.account_circle
                              : Icons.person_outline,
                          color: Theme.of(context).colorScheme.primary,
                          size: 22),
                    ),
                    title: Text(
                        account.isSignedIn ? account.displayName : 'Konto',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      account.isSignedIn
                          ? 'Poziom ${account.user!.level} — '
                              '${account.user!.levelName} • '
                              '${account.user!.points} pkt'
                          : 'Zaloguj się i zdobywaj punkty',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await showAccountScreen(context);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.forum,
                          color: Theme.of(context).colorScheme.primary,
                          size: 22),
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
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.settings,
                          color: Theme.of(context).colorScheme.primary,
                          size: 22),
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
