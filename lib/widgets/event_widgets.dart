import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/important_place.dart';
import '../models/road_event.dart';
import '../providers/events_provider.dart';
import '../services/location_service.dart';

IconData eventIcon(RoadEventType type) {
  switch (type) {
    case RoadEventType.police:
      return Icons.local_police;
    case RoadEventType.speedCamera:
      return Icons.photo_camera;
    case RoadEventType.accident:
      return Icons.car_crash;
    case RoadEventType.obstacle:
      return Icons.report_problem;
    case RoadEventType.breakdown:
      return Icons.build_circle_outlined;
  }
}

Color roadEventColor(RoadEventType type) {
  switch (type) {
    case RoadEventType.police:
      return Colors.blue;
    case RoadEventType.speedCamera:
      return Colors.red;
    case RoadEventType.accident:
      return Colors.deepOrange;
    case RoadEventType.obstacle:
      return Colors.orange;
    case RoadEventType.breakdown:
      return Colors.brown;
  }
}

class RoadEventMarker extends StatelessWidget {
  final RoadEventType type;
  final bool selected;
  const RoadEventMarker({super.key, required this.type, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: selected ? Colors.deepOrange : Colors.red, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 5)],
      ),
      child: Icon(Icons.warning, color: Colors.red, size: 28),
    );
  }
}

class ImportantPlaceMarker extends StatelessWidget {
  final bool selected;
  const ImportantPlaceMarker({super.key, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
            color: selected ? Colors.deepOrange : Colors.amber, width: 2.5),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 5)],
      ),
      child: const Icon(Icons.star, color: Colors.amber, size: 28),
    );
  }
}

Future<LatLng?> resolveReportLocation(
    LatLng fallback, BuildContext context) async {
  final gps = await LocationService.getCurrentLocation(
    timeout: const Duration(seconds: 4),
  );
  if (gps != null) return gps;
  return fallback;
}

Future<void> showEventReportSheet(
  BuildContext context, {
  required LatLng fallbackLocation,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final eventsVM = context.read<EventsProvider>();
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Zgłoś na drodze',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Wydarzenie będzie widoczne dla innych na mapie.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              for (final type in RoadEventType.values)
                _ReportRow(
                  icon: eventIcon(type),
                  color: Colors.red,
                  label: type.label,
                  onTap: () async {
                    final location =
                        await resolveReportLocation(fallbackLocation, ctx);
                    if (!ctx.mounted) return;
                    final messenger = ScaffoldMessenger.of(ctx);
                    if (location == null) {
                      messenger.showSnackBar(const SnackBar(
                          content:
                              Text('Nie udało się ustalić lokalizacji')));
                      return;
                    }
                    eventsVM.addRoadEvent(
                        type: type, location: location, description: null);
                    Navigator.of(ctx).pop();
                    messenger.showSnackBar(SnackBar(
                      content: Text('Zgłoszono: ${type.label}'),
                      duration: const Duration(seconds: 2),
                    ));
                  },
                ),
              const Divider(height: 24),
              _ReportRow(
                icon: Icons.star,
                color: Colors.amber,
                label: 'Ważne miejsce',
                subtitle: 'Nazwa, notatka i zdjęcie',
                onTap: () async {
                  final location =
                      await resolveReportLocation(fallbackLocation, ctx);
                  if (!ctx.mounted) return;
                  final messenger = ScaffoldMessenger.of(ctx);
                  Navigator.of(ctx).pop();
                  if (location == null) {
                    messenger.showSnackBar(const SnackBar(
                        content:
                            Text('Nie udało się ustalić lokalizacji')));
                    return;
                  }
                  showImportantPlaceSheet(context, location: location);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ReportRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _ReportRow({
    required this.icon,
    required this.color,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: const TextStyle(fontSize: 12))
          : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

Future<void> showImportantPlaceSheet(
  BuildContext context, {
  required LatLng location,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    builder: (ctx) => _ImportantPlaceForm(location: location),
  );
}

class _ImportantPlaceForm extends StatefulWidget {
  final LatLng location;
  const _ImportantPlaceForm({required this.location});

  @override
  State<_ImportantPlaceForm> createState() => _ImportantPlaceFormState();
}

class _ImportantPlaceFormState extends State<_ImportantPlaceForm> {
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();
  String? _photoBase64;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _photoBase64 = base64Encode(bytes));
    } catch (_) {}
  }

  void _save() {
    final name = _nameController.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (name.isEmpty) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Podaj nazwę miejsca')));
      return;
    }
    setState(() => _saving = true);
    context.read<EventsProvider>().addImportantPlace(
          name: name,
          note: _noteController.text.trim(),
          photoBase64: _photoBase64,
          location: widget.location,
        );
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(
      content: Text('Dodano ważne miejsce'),
      duration: Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Ważne miejsce',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Miejsce warte uwagi dla innych motocyklistów.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nazwa miejsca',
                hintText: 'np. Panorama ze Szklarki',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Notatka',
                hintText: 'Dlaczego warto się zatrzymać?',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(_photoBase64 == null
                  ? 'Dodaj zdjęcie'
                  : 'Zmień zdjęcie'),
            ),
            if (_photoBase64 != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(_photoBase64!),
                  height: 160,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    label: const Text('Anuluj'),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.check),
                    label: const Text('Zapisz miejsce'),
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime time) {
  return DateFormat('HH:mm, dd.MM').format(time.toLocal());
}

Future<void> showEventDetail(BuildContext context, RoadEvent event) async {
  await showModalBottomSheet(
    context: context,
    builder: (ctx) {
      final eventsVM = context.read<EventsProvider>();
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.red.withValues(alpha: 0.15),
                    child: Icon(eventIcon(event.type),
                        color: Colors.red, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(event.type.label,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Zgłoszono: ${_formatTime(event.createdAt)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              if (event.description != null &&
                  event.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(event.description!,
                    style: const TextStyle(fontSize: 14)),
              ],
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () {
                  eventsVM.removeRoadEvent(event.id);
                  Navigator.of(ctx).pop();
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('Usuń zgłoszenie',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showImportantPlaceDetail(
    BuildContext context, ImportantPlace place) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final eventsVM = context.read<EventsProvider>();
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.amber,
                    child: Icon(Icons.star, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(place.name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Dodano: ${_formatTime(place.createdAt)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              if (place.photoBase64 != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    base64Decode(place.photoBase64!),
                    height: 220,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              if (place.note.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(place.note, style: const TextStyle(fontSize: 14)),
              ],
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () {
                  eventsVM.removeImportantPlace(place.id);
                  Navigator.of(ctx).pop();
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('Usuń miejsce',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      );
    },
  );
}
