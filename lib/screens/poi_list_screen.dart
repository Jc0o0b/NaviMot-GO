import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/point_of_interest.dart';
import '../providers/poi_provider.dart';
import '../providers/route_provider.dart';
import '../widgets/section_header.dart';

class POIListScreen extends StatelessWidget {
  final VoidCallback? onShowOnMap;

  const POIListScreen({super.key, this.onShowOnMap});

  @override
  Widget build(BuildContext context) {
    return Consumer2<POIProvider, RouteProvider>(
      builder: (context, poiVM, routeVM, _) {
        final hasRoute = routeVM.currentRoute != null;

        return Scaffold(
          body: Column(
            children: [
              const SectionHeader(
                  title: 'Miejsca dla motocyklisty', icon: Icons.pin_drop),
              if (hasRoute && poiVM.pointsOfInterest.isNotEmpty)
                _buildCategoryFilter(context, poiVM),
              if (poiVM.isLoading)
                const Expanded(
                    child: Center(child: CircularProgressIndicator()))
              else if (poiVM.errorMessage != null)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off,
                            size: 64, color: Colors.grey[600]),
                        const SizedBox(height: 16),
                        Text(
                          'Nie udało się pobrać miejsc.\nSpróbuj ponownie później.',
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else if (!hasRoute || poiVM.pointsOfInterest.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pin_drop, size: 64, color: Colors.grey[600]),
                        const SizedBox(height: 16),
                        Text(
                          hasRoute
                              ? 'Brak miejsc dla motocyklisty w okolicy'
                              : 'Wyznacz trasę, aby znaleźć miejsca',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: poiVM.filteredPOIs.length,
                    itemBuilder: (_, i) =>
                        _buildPOIRow(context, poiVM, poiVM.filteredPOIs[i]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryFilter(BuildContext context, POIProvider poiVM) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildChip(context, 'Wszystkie', null, poiVM.selectedCategory == null,
              () {
            poiVM.selectCategory(null);
          }),
          ...poiVM.categoryCounts.map((entry) => _buildChip(
                context,
                '${entry.key.label} (${entry.value})',
                entry.key,
                poiVM.selectedCategory == entry.key,
                () => poiVM.selectCategory(entry.key),
              )),
        ],
      ),
    );
  }

  Widget _buildChip(BuildContext context, String label, POICategory? category,
      bool selected, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: scheme.secondaryContainer,
        checkmarkColor: scheme.onSecondaryContainer,
      ),
    );
  }

  Widget _buildPOIRow(
      BuildContext context, POIProvider poiVM, PointOfInterest poi) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        child: Icon(poiIconFromString(poi.category.iconName),
            color: scheme.primary, size: 20),
      ),
      title:
          Text(poi.name, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(poi.category.label, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showPOIDetail(context, poi),
    );
  }

  void _showPOIDetail(BuildContext context, PointOfInterest poi) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Icon(poiIconFromString(poi.category.iconName),
                  size: 48, color: scheme.primary),
            ),
            const SizedBox(height: 16),
            Text(poi.name,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(poiIconFromString(poi.category.iconName),
                    size: 16, color: scheme.primary),
                const SizedBox(width: 4),
                Text(poi.category.label,
                    style: TextStyle(color: scheme.primary)),
              ],
            ),
            const SizedBox(height: 12),
            Text(poi.description,
                style: const TextStyle(fontSize: 14, height: 1.4)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.read<POIProvider>().selectPOI(poi);
                  onShowOnMap?.call();
                },
                icon: const Icon(Icons.map, size: 18),
                label: const Text('Pokaż na mapie'),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zamknij'),
            ),
          ],
        ),
      ),
    );
  }
}

IconData poiIconFromString(String name) {
  switch (name) {
    case 'binoculars':
      return Icons.visibility;
    case 'terrain':
      return Icons.terrain;
    case 'route':
      return Icons.route;
    case 'restaurant':
      return Icons.restaurant;
    case 'hotel':
      return Icons.hotel;
    case 'local_gas_station':
      return Icons.local_gas_station;
    case 'build':
      return Icons.build;
    default:
      return Icons.pin_drop;
  }
}
