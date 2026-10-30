import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../domain/map_models.dart';
import 'map_providers.dart';

final mapSurfaceBuilderProvider = Provider<WidgetBuilder>(
  (ref) =>
      (_) => const NativeMapSurface(),
);

class NativeMapSurface extends ConsumerStatefulWidget {
  const NativeMapSurface({super.key});
  @override
  ConsumerState<NativeMapSurface> createState() => _NativeMapSurfaceState();
}

class _NativeMapSurfaceState extends ConsumerState<NativeMapSurface> {
  static const _initial = CameraPosition(
    target: LatLng(21.0285, 105.8542),
    zoom: 16,
    tilt: 55,
  );
  MapLibreMapController? _controller;
  MapSessionState? _painted;
  Future<void> _paintQueue = Future.value();
  Timer? _timeout;
  bool _ready = false;
  int _version = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimeout();
  }

  void _startTimeout() {
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 25), () {
      if (mounted && !_ready) {
        setState(
          () => _error = 'Chưa tải được bản đồ. Kiểm tra mạng rồi thử lại.',
        );
      }
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  Map<String, dynamic> _collection(List<Map<String, dynamic>> features) => {
    'type': 'FeatureCollection',
    'features': features,
  };
  Map<String, dynamic> _point(
    GeoPoint point, [
    Map<String, dynamic> properties = const {},
  ]) => {
    'type': 'Feature',
    'geometry': {'type': 'Point', 'coordinates': point.coordinates},
    'properties': properties,
  };

  Future<void> _loaded() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      for (final source in ['route', 'traffic', 'position', 'destination']) {
        await controller.addGeoJsonSource('taxi-$source', _collection([]));
      }
      await controller.addLineLayer(
        'taxi-route',
        'taxi-route-line',
        const LineLayerProperties(
          lineColor: '#1674ec',
          lineWidth: 6,
          lineOpacity: 0.85,
        ),
        belowLayerId: 'building-3d',
        enableInteraction: false,
      );
      await controller.addCircleLayer(
        'taxi-traffic',
        'taxi-traffic-points',
        const CircleLayerProperties(
          circleRadius: 6,
          circleColor: ['get', 'color'],
          circleStrokeColor: '#ffffff',
          circleStrokeWidth: 2,
        ),
        enableInteraction: false,
      );
      await controller.addCircleLayer(
        'taxi-position',
        'taxi-position-point',
        const CircleLayerProperties(
          circleRadius: 8,
          circleColor: '#1674ec',
          circleStrokeColor: '#ffffff',
          circleStrokeWidth: 3,
        ),
        enableInteraction: false,
      );
      await controller.addCircleLayer(
        'taxi-destination',
        'taxi-destination-point',
        const CircleLayerProperties(
          circleRadius: 9,
          circleColor: '#f58118',
          circleStrokeColor: '#ffffff',
          circleStrokeWidth: 3,
        ),
        enableInteraction: false,
      );
      if (!mounted || controller != _controller) return;
      _timeout?.cancel();
      setState(() {
        _ready = true;
        _error = null;
      });
      _queuePaint(ref.read(mapSessionProvider));
    } catch (_) {
      if (mounted && controller == _controller) {
        setState(() => _error = 'Không thể hiển thị bản đồ. Thử tải lại.');
      }
    }
  }

  void _queuePaint(MapSessionState state) {
    final controller = _controller;
    if (!_ready || controller == null) return;
    _paintQueue = _paintQueue
        .then((_) async {
          if (!mounted || controller != _controller) return;
          final previous = _painted;
          if (previous?.is3D != state.is3D) {
            await controller.setLayerVisibility('building-3d', state.is3D);
            final camera = controller.cameraPosition ?? _initial;
            await controller.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: camera.target,
                  zoom: camera.zoom,
                  bearing: camera.bearing,
                  tilt: state.is3D ? 55 : 0,
                ),
              ),
            );
          }
          if (previous?.fix != state.fix) {
            await controller.setGeoJsonSource(
              'taxi-position',
              _collection(state.fix == null ? [] : [_point(state.fix!.point)]),
            );
          }
          if (previous?.destination != state.destination) {
            await controller.setGeoJsonSource(
              'taxi-destination',
              _collection(
                state.destination == null
                    ? []
                    : [_point(state.destination!.point)],
              ),
            );
            if (state.destination != null) {
              await controller.animateCamera(
                CameraUpdate.newLatLngZoom(
                  _latLng(state.destination!.point),
                  16,
                ),
              );
            }
          }
          if (previous?.traffic != state.traffic) {
            await controller.setGeoJsonSource(
              'taxi-traffic',
              _collection(
                state.traffic?.features
                        .map(
                          (f) => _point(f.point, {
                            'color': f.isSpeedTag ? '#3474ce' : '#df483f',
                          }),
                        )
                        .toList() ??
                    [],
              ),
            );
          }
          if (previous?.route != state.route) {
            await controller.setGeoJsonSource(
              'taxi-route',
              _collection(
                state.route == null
                    ? []
                    : [
                        {
                          'type': 'Feature',
                          'properties': <String, dynamic>{},
                          'geometry': {
                            'type': 'LineString',
                            'coordinates': state.route!.points
                                .map((p) => p.coordinates)
                                .toList(),
                          },
                        },
                      ],
              ),
            );
            if (state.route != null) {
              final points = state.route!.points;
              final south = points.map((p) => p.latitude).reduce(math.min);
              final north = points.map((p) => p.latitude).reduce(math.max);
              final west = points.map((p) => p.longitude).reduce(math.min);
              final east = points.map((p) => p.longitude).reduce(math.max);
              await controller.animateCamera(
                CameraUpdate.newLatLngBounds(
                  LatLngBounds(
                    southwest: LatLng(south, west),
                    northeast: LatLng(north, east),
                  ),
                  left: 40,
                  right: 40,
                  top: 120,
                  bottom: 200,
                ),
              );
            }
          }
          if (state.follow &&
              state.gpsActive &&
              state.fix != null &&
              (previous?.fix != state.fix || previous?.follow != true)) {
            await controller.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: _latLng(state.fix!.point),
                  zoom: 17,
                  tilt: state.is3D ? 55 : 0,
                  bearing:
                      state.fix!.heading ??
                      controller.cameraPosition?.bearing ??
                      0,
                ),
              ),
            );
          }
          _painted = state;
        })
        .catchError((Object _) {
          if (mounted && controller == _controller) {
            setState(
              () => _error = 'Không cập nhật được lớp bản đồ. Thử tải lại.',
            );
          }
        });
  }

  LatLng _latLng(GeoPoint point) => LatLng(point.latitude, point.longitude);
  void _reload() {
    setState(() {
      _controller = null;
      _ready = false;
      _error = null;
      _painted = null;
      _paintQueue = Future.value();
      _version++;
    });
    _startTimeout();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(mapSessionProvider, (_, next) => _queuePaint(next));
    return Stack(
      fit: StackFit.expand,
      children: [
        Listener(
          onPointerDown: (_) =>
              ref.read(mapSessionProvider.notifier).stopFollowing(),
          child: MapLibreMap(
            key: ValueKey(_version),
            styleString: 'https://tiles.openfreemap.org/styles/liberty',
            initialCameraPosition: _initial,
            trackCameraPosition: true,
            attributionButtonPosition: AttributionButtonPosition.bottomRight,
            compassViewPosition: CompassViewPosition.bottomRight,
            onMapCreated: (controller) => _controller = controller,
            onStyleLoadedCallback: _loaded,
            onMapLongClick: (_, point) => ref
                .read(mapSessionProvider.notifier)
                .selectDestination(
                  MapPlace(
                    'Điểm đã chọn: ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
                    GeoPoint(point.latitude, point.longitude),
                  ),
                ),
          ),
        ),
        if (!_ready || _error != null)
          Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error ?? 'Đang tải bản đồ…',
                      textAlign: TextAlign.center,
                    ),
                    if (_error != null)
                      TextButton(
                        onPressed: _reload,
                        child: const Text('Tải lại'),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
