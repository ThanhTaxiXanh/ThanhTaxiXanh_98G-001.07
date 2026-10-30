import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/map_models.dart';
import 'map_providers.dart';
import 'native_map_surface.dart';
import 'place_search_screen.dart';

class DrivingMap extends ConsumerStatefulWidget {
  const DrivingMap({super.key});
  @override
  ConsumerState<DrivingMap> createState() => _DrivingMapState();
}

class _DrivingMapState extends ConsumerState<DrivingMap>
    with WidgetsBindingObserver {
  bool _resumeGps = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      final current = ref.read(mapSessionProvider);
      _resumeGps = _resumeGps || current.gpsActive || current.requestingGps;
      ref.read(mapSessionProvider.notifier).pauseGps();
    } else if (state == AppLifecycleState.resumed && _resumeGps) {
      _resumeGps = false;
      ref.read(mapSessionProvider.notifier).enableGps();
    }
  }

  Future<void> _search() async {
    final place = await Navigator.of(context).push<MapPlace>(
      MaterialPageRoute(builder: (_) => const PlaceSearchScreen()),
    );
    if (mounted && place != null) {
      ref.read(mapSessionProvider.notifier).selectDestination(place);
    }
  }

  void _trafficDetails(MapSessionState state) {
    final nearby = state.fix == null
        ? <TrafficFeature>[]
        : state.traffic?.nearby(state.fix!.point) ?? [];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Biển báo và dữ liệu các đường lân cận (OSM)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Dữ liệu có thể thiếu. Tham khảo biển báo thực tế.',
                ),
              ),
              if (state.traffic != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'Dữ liệu lúc ${state.traffic!.fetchedAt.toUtc().add(const Duration(hours: 7)).hour.toString().padLeft(2, '0')}:'
                    '${state.traffic!.fetchedAt.toUtc().add(const Duration(hours: 7)).minute.toString().padLeft(2, '0')}',
                  ),
                ),
              Expanded(
                child: nearby.isEmpty
                    ? const Center(
                        child: Text('Chưa có dữ liệu OSM gần vị trí này.'),
                      )
                    : ListView.builder(
                        itemCount: nearby.length,
                        itemBuilder: (_, i) => ListTile(
                          leading: Icon(
                            nearby[i].isSpeedTag
                                ? Icons.speed
                                : Icons.warning_amber,
                          ),
                          title: Text(nearby[i].label),
                          subtitle: Text(
                            formatDistance(
                              nearby[i].point.distanceTo(state.fix!.point),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _routeDetails(RoutePlan route) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Hướng đi dự kiến',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: route.steps.length,
                  itemBuilder: (_, i) {
                    final step = route.steps[i];
                    return ListTile(
                      leading: Text('${i + 1}'),
                      title: Text(step.instruction),
                      subtitle: Text(formatDistance(step.distance)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mapSessionProvider);
    final actions = ref.read(mapSessionProvider.notifier);
    final nearby = state.fix == null
        ? <TrafficFeature>[]
        : state.traffic?.nearby(state.fix!.point) ?? [];
    return LayoutBuilder(
      builder: (context, size) => Stack(
        fit: StackFit.expand,
        children: [
          ref.watch(mapSurfaceBuilderProvider)(context),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            key: const Key('open-place-search'),
                            onPressed: _search,
                            icon: const Icon(Icons.search),
                            label: const Text('Tìm điểm đến'),
                          ),
                        ),
                        TextButton(
                          key: const Key('toggle-map-3d'),
                          onPressed: actions.toggle3D,
                          child: Text(state.is3D ? '3D' : '2D'),
                        ),
                        IconButton(
                          key: const Key('enable-gps'),
                          tooltip: 'Về vị trí của tôi',
                          onPressed: state.requestingGps
                              ? null
                              : actions.enableGps,
                          icon: Icon(
                            state.follow && state.gpsActive
                                ? Icons.gps_fixed
                                : Icons.my_location,
                          ),
                        ),
                        if (state.gpsActive)
                          IconButton(
                            tooltip: 'Tạm dừng GPS',
                            onPressed: actions.pauseGps,
                            icon: const Icon(Icons.location_off_outlined),
                          ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${state.gpsActive ? state.fix?.speedKmh?.toStringAsFixed(0) ?? '—' : '—'} km/h',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                          Text(
                            state.requestingGps
                                ? 'Đang xin quyền vị trí…'
                                : !state.gpsActive
                                ? 'GPS đang tắt'
                                : state.fix == null
                                ? 'Đang chờ GPS…'
                                : 'GPS · Sai số khoảng ${state.fix!.accuracyMeters.round()} m',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 40,
            left: 12,
            right: 12,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: (size.maxHeight * 0.36).clamp(100, 220),
              ),
              child: SingleChildScrollView(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (state.message != null)
                          Text(
                            state.message!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        if (state.destination == null)
                          const Text(
                            'Tìm địa chỉ hoặc nhấn giữ trên bản đồ để chọn điểm đến.',
                          )
                        else ...[
                          Text(
                            state.destination!.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (state.route != null)
                            Text(
                              '${formatDistance(state.route!.distanceMeters)} · '
                              'Khoảng ${(state.route!.durationSeconds / 60).ceil()} phút',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          Wrap(
                            spacing: 8,
                            children: [
                              FilledButton(
                                key: const Key('preview-route'),
                                onPressed: state.loadingRoute
                                    ? null
                                    : actions.fetchRoute,
                                child: Text(
                                  state.loadingRoute
                                      ? 'Đang tính tuyến…'
                                      : 'Xem tuyến ô tô',
                                ),
                              ),
                              if (state.route != null)
                                TextButton(
                                  onPressed: () => _routeDetails(state.route!),
                                  child: const Text('Hướng đi'),
                                ),
                              TextButton(
                                onPressed: actions.clearDestination,
                                child: const Text('Xóa đích'),
                              ),
                            ],
                          ),
                          const Text('Xem trước tuyến đường · OSRM'),
                        ],
                        if (state.trafficMessage != null)
                          Text(state.trafficMessage!),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              key: const Key('show-traffic'),
                              onPressed: () => _trafficDetails(state),
                              icon: const Icon(Icons.traffic_outlined),
                              label: Text('OSM lân cận (${nearby.length})'),
                            ),
                            IconButton(
                              tooltip: 'Cập nhật dữ liệu OSM',
                              onPressed:
                                  !state.gpsActive || state.loadingTraffic
                                  ? null
                                  : () => actions.refreshTraffic(manual: true),
                              icon: const Icon(Icons.refresh),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            bottom: 8,
            left: 8,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.white70),
                child: Padding(
                  padding: EdgeInsets.all(2),
                  child: Text(
                    '© OpenStreetMap · OpenFreeMap',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bản đồ 3D')),
    body: const SafeArea(child: DrivingMap()),
  );
}
