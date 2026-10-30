import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/map_models.dart';
import '../../../core/network/bounded_http.dart';

class OsmMapRepository implements MapRepository {
  OsmMapRepository(this.client, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final http.Client client;
  final DateTime Function() _now;
  static const _headers = {
    'User-Agent':
        'ThanhTaxiXanh/0.2.0 (+https://github.com/ThanhTaxiXanh/ThanhTaxiXanh_98G-001.07)',
    'Accept': 'application/json',
  };
  final _searchCache = <String, List<MapPlace>>{};
  DateTime? _lastSearch;
  TrafficSnapshot? _trafficCache;

  Future<Object?> _get(Uri url) async {
    try {
      final bytes = await boundedGet(client, url, headers: _headers);
      return jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const MapServiceException(
        'Dịch vụ bản đồ tạm thời không phản hồi. Vui lòng thử lại sau.',
      );
    }
  }

  GeoPoint _point(Object? lat, Object? lon) {
    final latitude = lat is num ? lat.toDouble() : double.tryParse('$lat');
    final longitude = lon is num ? lon.toDouble() : double.tryParse('$lon');
    if (latitude == null || longitude == null) {
      throw const FormatException('Invalid coordinates');
    }
    final point = GeoPoint(latitude, longitude);
    if (!point.isValid) throw const FormatException('Coordinates out of range');
    return point;
  }

  @override
  Future<List<MapPlace>> search(String query) async {
    final term = query.trim();
    if (term.length < 3 || term.length > 200) {
      throw const MapServiceException('Nhập địa chỉ từ 3 đến 200 ký tự.');
    }
    final cached = _searchCache[term.toLowerCase()];
    if (cached != null) return cached;
    // Nominatim permits explicit searches, not autocomplete. Pace requests to
    // at most one per second and cache repeated queries for this session.
    final previous = _lastSearch;
    if (previous != null && _now().difference(previous).inMilliseconds < 1100) {
      throw const MapServiceException(
        'Vui lòng chờ một giây trước khi tìm tiếp.',
      );
    }
    _lastSearch = _now();
    final json = await _get(
      Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': term,
        'format': 'jsonv2',
        'limit': '5',
        'countrycodes': 'vn',
        'accept-language': 'vi',
      }),
    );
    if (json is! List) throw const FormatException('Invalid search response');
    final results = json.take(5).map((row) {
      final place = row as Map<String, dynamic>;
      final name = place['display_name'];
      if (name is! String || name.isEmpty) {
        throw const FormatException('Missing place name');
      }
      return MapPlace(name, _point(place['lat'], place['lon']));
    }).toList();
    if (_searchCache.length >= 30) _searchCache.remove(_searchCache.keys.first);
    _searchCache[term.toLowerCase()] = results;
    return results;
  }

  @override
  Future<RoutePlan> route(GeoPoint from, GeoPoint to) async {
    if (!from.isValid || !to.isValid) {
      throw ArgumentError('Invalid route coordinates');
    }
    final path =
        '/route/v1/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
    final json =
        await _get(
              Uri.https('router.project-osrm.org', path, {
                'overview': 'full',
                'geometries': 'geojson',
                'steps': 'true',
                'alternatives': 'false',
              }),
            )
            as Map<String, dynamic>;
    final routes = json['routes'];
    if (json['code'] != 'Ok' || routes is! List || routes.isEmpty) {
      throw const MapServiceException(
        'Không tìm được tuyến ô tô tới điểm đã chọn.',
      );
    }
    final route = routes.first as Map<String, dynamic>;
    final coordinates =
        (route['geometry'] as Map<String, dynamic>)['coordinates'];
    if (coordinates is! List ||
        coordinates.length < 2 ||
        coordinates.length > 30000) {
      throw const FormatException('Invalid route geometry');
    }
    final points = coordinates.map((c) {
      if (c is! List || c.length < 2) {
        throw const FormatException('Invalid route point');
      }
      return _point(c[1], c[0]);
    }).toList();
    final distance = (route['distance'] as num).toDouble();
    final duration = (route['duration'] as num).toDouble();
    if (!distance.isFinite ||
        !duration.isFinite ||
        distance < 0 ||
        duration < 0) {
      throw const FormatException('Invalid route metrics');
    }
    final steps = <RouteStep>[];
    for (final leg in route['legs'] as List) {
      for (final step in (leg as Map)['steps'] as List) {
        final maneuver = step['maneuver'] as Map;
        steps.add(
          RouteStep(
            name: step['name'] as String? ?? '',
            type: maneuver['type'] as String? ?? 'continue',
            modifier: maneuver['modifier'] as String? ?? '',
            distance: (step['distance'] as num).toDouble(),
          ),
        );
      }
    }
    return RoutePlan(
      points: points,
      distanceMeters: distance,
      durationSeconds: duration,
      steps: steps,
    );
  }

  @override
  Future<TrafficSnapshot> traffic(GeoPoint point) async {
    if (!point.isValid) throw ArgumentError('Invalid traffic coordinates');
    final cached = _trafficCache;
    if (cached != null &&
        cached.center.distanceTo(point) < 250 &&
        _now().difference(cached.fetchedAt) < const Duration(minutes: 2)) {
      return cached;
    }
    // Limit radius, execution time and output count. Road centers are displayed
    // as nearby OSM records; proximity cannot identify the current road's limit.
    final around = 'around:1000,${point.latitude},${point.longitude}';
    final query =
        '[out:json][timeout:15];('
        'node($around)["traffic_sign"];way($around)["maxspeed"];);out body center 80;';
    final json =
        await _get(
              Uri.https('overpass-api.de', '/api/interpreter', {'data': query}),
            )
            as Map<String, dynamic>;
    if (json['remark'] is String) {
      throw const MapServiceException(
        'Dữ liệu OSM đang bận. Vui lòng thử lại sau.',
      );
    }
    final elements = json['elements'];
    if (elements is! List) {
      throw const FormatException('Invalid Overpass response');
    }
    final features = <TrafficFeature>[];
    for (final raw in elements.take(80)) {
      final row = raw as Map<String, dynamic>;
      final tags = row['tags'] as Map<String, dynamic>?;
      if (tags == null) continue;
      final center = row['center'] as Map<String, dynamic>? ?? row;
      GeoPoint position;
      try {
        position = _point(center['lat'], center['lon']);
      } on FormatException {
        continue;
      }
      final speed = tags['maxspeed'];
      final sign = tags['traffic_sign'];
      if (speed is! String && sign is! String) continue;
      final label = speed is String
          ? '${tags['name'] ?? 'Đường chưa có tên'} · maxspeed: $speed'
          : 'Biển báo ${sign!}';
      features.add(
        TrafficFeature(
          id: '${row['type']}/${row['id']}',
          point: position,
          label: label,
          isSpeedTag: speed is String,
        ),
      );
    }
    return _trafficCache = TrafficSnapshot(point, features, _now().toUtc());
  }
}
