import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/home_address.dart';
import '../providers/settings_provider.dart';
import '../services/geocoding_service.dart';

Future<void> showHomeSheet(
  BuildContext context, {
  void Function(HomeAddress)? onUseAsStart,
}) {
  final settings = context.read<SettingsProvider>();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _HomeSheet(settings: settings, onUseAsStart: onUseAsStart),
  );
}

class _HomeSheet extends StatefulWidget {
  final SettingsProvider settings;
  final void Function(HomeAddress)? onUseAsStart;

  const _HomeSheet({required this.settings, this.onUseAsStart});

  @override
  State<_HomeSheet> createState() => _HomeSheetState();
}

class _HomeSheetState extends State<_HomeSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<GeocodingResult> _results = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final home = widget.settings.home;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Adres domowy',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Użyj adresu domowego jako punktu startu lub celu.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            if (home != null) ...[
              const SizedBox(height: 12),
              Card(
                color: Colors.orange.shade50,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.home,
                          color: Colors.deepOrange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(home.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (widget.onUseAsStart != null)
                        IconButton(
                          tooltip: 'Użyj jako start',
                          icon: const Icon(Icons.play_arrow,
                              color: Colors.green),
                          onPressed: () => widget.onUseAsStart!(home),
                        ),
                      IconButton(
                        tooltip: 'Usuń',
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => widget.settings.clearHome(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Wpisz adres domowy...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (q) => _onSearch(q),
            ),
            if (_results.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (_, i) => ListTile(
                    dense: true,
                    title: Text(_results[i].displayName,
                        style: const TextStyle(fontSize: 13)),
                    onTap: () {
                      final r = _results[i];
                      widget.settings.setHome(HomeAddress(
                        name: r.displayName,
                        lat: r.lat,
                        lon: r.lon,
                      ));
                      setState(() => _results = []);
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onSearch(String query) {
    _debounce?.cancel();
    if (query.length < 3) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final results = await GeocodingService.shared.search(query);
      if (mounted) setState(() => _results = results);
    });
  }
}
