import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../providers/account_provider.dart';

/// Pokazuje ekran konta. Zwraca true, jeśli po zamknięciu użytkownik jest
/// zalogowany.
Future<bool> showAccountScreen(BuildContext context) async {
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const AccountScreen()),
  );
  if (!context.mounted) return false;
  return context.read<AccountProvider>().isSignedIn;
}

/// Wymusza zalogowanie przed akcją (zgłoszenie/potwierdzenie/zdobycie punktów).
/// Zwraca true, gdy użytkownik jest zalogowany.
Future<bool> ensureSignedIn(
  BuildContext context, {
  required String action,
}) async {
  final account = context.read<AccountProvider>();
  if (account.isSignedIn) return true;
  final go = await showModalBottomSheet<bool>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: const [
                Icon(Icons.lock_outline, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Zaloguj się, aby kontynuować',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Aby $action, załóż konto lub zaloguj się. Za zgłoszenia '
              'i potwierdzenia zdobywasz punkty i awansujesz na wyższe poziomy.',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.of(ctx).pop(true),
              icon: const Icon(Icons.login),
              label: const Text('Przejdź do konta'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Nie teraz'),
            ),
          ],
        ),
      ),
    ),
  );
  if (go != true || !context.mounted) return false;
  return showAccountScreen(context);
}

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _nickController = TextEditingController();
  bool _registerMode = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _nickController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Konto')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (account.isSignedIn)
            _SignedInView(account: account)
          else
            _SignedOutView(
              account: account,
              emailController: _emailController,
              passwordController: _passwordController,
              nameController: _nameController,
              nickController: _nickController,
              registerMode: _registerMode,
              onToggleMode: () =>
                  setState(() => _registerMode = !_registerMode),
            ),
        ],
      ),
    );
  }
}

class _SignedInView extends StatelessWidget {
  final AccountProvider account;
  const _SignedInView({required this.account});

  @override
  Widget build(BuildContext context) {
    final user = account.user!;
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: primary.withValues(alpha: 0.15),
                  child: Text(
                    user.displayName.characters.first.toUpperCase(),
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: primary),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.displayName,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        user.email ??
                            (account.isRemoteAuth
                                ? 'Konto online'
                                : 'Konto lokalne'),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _LevelCard(user: user),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                  icon: Icons.report,
                  color: Colors.red,
                  value: '${user.reports}',
                  label: 'Zgłoszenia'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                  icon: Icons.verified,
                  color: Colors.green,
                  value: '${user.confirmations}',
                  label: 'Potwierdzenia'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => account.signOut(),
          icon: const Icon(Icons.logout),
          label: const Text('Wyloguj się'),
          style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12)),
        ),
        const SizedBox(height: 12),
        const Text(
          'Punkty: +${PointsRules.report} za zgłoszenie, '
          '+${PointsRules.confirmation} za potwierdzenie zdarzenia, '
          '+${PointsRules.placeAdded} za ważne miejsce.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  final UserProfile user;
  const _LevelCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final next = user.pointsForNextLevel;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.workspace_premium, color: primary),
                const SizedBox(width: 8),
                Text('Poziom ${user.level} — ${user.levelName}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${user.points} pkt',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: primary)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: user.progressToNextLevel,
                minHeight: 10,
                backgroundColor: primary.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              next == null
                  ? 'Osiągnięto najwyższy poziom!'
                  : 'Do następnego poziomu: ${next - user.points} pkt',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _StatCard(
      {required this.icon,
      required this.color,
      required this.value,
      required this.label});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _SignedOutView extends StatefulWidget {
  final AccountProvider account;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController nameController;
  final TextEditingController nickController;
  final bool registerMode;
  final VoidCallback onToggleMode;

  const _SignedOutView({
    required this.account,
    required this.emailController,
    required this.passwordController,
    required this.nameController,
    required this.nickController,
    required this.registerMode,
    required this.onToggleMode,
  });

  @override
  State<_SignedOutView> createState() => _SignedOutViewState();
}

class _SignedOutViewState extends State<_SignedOutView> {
  Future<void> _submitEmail() async {
    FocusScope.of(context).unfocus();
    final ok = widget.registerMode
        ? await widget.account.signUpWithEmail(
            email: widget.emailController.text,
            password: widget.passwordController.text,
            displayName: widget.nameController.text,
          )
        : await widget.account.signInWithEmail(
            email: widget.emailController.text,
            password: widget.passwordController.text,
          );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(widget.account.error ?? 'Nie udało się zalogować')));
    }
  }

  Future<void> _submitNick() async {
    FocusScope.of(context).unfocus();
    final ok =
        await widget.account.quickSignIn(nickname: widget.nickController.text);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(widget.account.error ?? 'Nie udało się zalogować')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.info_outline),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Przeglądaj mapę i planuj trasy bez konta. Aby zgłaszać '
                    'zdarzenia, potwierdzać je i zdobywać punkty, zaloguj się.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.registerMode ? 'Rejestracja' : 'Logowanie',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (widget.registerMode) ...[
                  TextField(
                    controller: widget.nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nazwa / pseudonim',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: widget.emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: widget.passwordController,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(
                    labelText: 'Hasło',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: account.isBusy ? null : _submitEmail,
                  icon: Icon(
                      widget.registerMode ? Icons.person_add : Icons.login),
                  label: Text(
                      widget.registerMode ? 'Zarejestruj się' : 'Zaloguj się'),
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
                TextButton(
                  onPressed: widget.onToggleMode,
                  child: Text(widget.registerMode
                      ? 'Masz już konto? Zaloguj się'
                      : 'Nie masz konta? Zarejestruj się'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Szybkie logowanie',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Bez hasła — wystarczy pseudonim.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 12),
                TextField(
                  controller: widget.nickController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Pseudonim',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: account.isBusy ? null : _submitNick,
                  icon: const Icon(Icons.flash_on),
                  label: const Text('Wejdź'),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Logowanie przez Google i Facebook (Firebase) pojawi się po '
          'podłączeniu backendu. Konta działają teraz lokalnie na urządzeniu.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
