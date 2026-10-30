import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taxi_auto/features/map/data/osm_map_repository.dart';
import 'package:taxi_auto/features/map/domain/map_models.dart';

void main() {
  test(
    'Haversine distance and GPS units handle valid and unavailable readings',
    () {
      expect(
        const GeoPoint(0, 0).distanceTo(const GeoPoint(0, 1)),
        closeTo(111195, 2),
      );
      expect(const GeoPoint(21, 105).distanceTo(const GeoPoint(21, 105)), 0);
      expect(const GeoPoint(91, 0).isValid, isFalse);
      GpsFix fix(double value) => GpsFix(
        point: const GeoPoint(21, 105),
        accuracyMeters: 5,
        recordedAt: DateTime.utc(2026),
        speedMetersPerSecond: value,
      );
      expect(fix(10).speedKmh, 36);
      expect(fix(-1).speedKmh, isNull);
      expect(fix(double.nan).speedKmh, isNull);
    },
  );

  test('address searches are explicit, identified, cached and paced', () async {
    var now = DateTime.utc(2026, 10, 30);
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.url.host, 'nominatim.openstreetmap.org');
      expect(request.url.queryParameters['countrycodes'], 'vn');
      expect(request.headers['User-Agent'], contains('ThanhTaxiXanh'));
      return http.Response(
        jsonEncode([
          {'display_name': 'Hồ Hoàn Kiếm', 'lat': '21.0285', 'lon': '105.8542'},
        ]),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    addTearDown(client.close);
    final repo = OsmMapRepository(client, now: () => now);
    final results = await repo.search('Hồ Hoàn Kiếm');
    expect(results.single.name, 'Hồ Hoàn Kiếm');
    expect(results.single.point.latitude, 21.0285);
    expect(await repo.search('hồ hoàn kiếm'), same(results));
    await expectLater(
      repo.search('Bắc Giang'),
      throwsA(isA<MapServiceException>()),
    );
    expect(calls, 1);
    now = now.add(const Duration(seconds: 2));
    await repo.search('Bắc Giang');
    expect(calls, 2);
    await expectLater(repo.search('a'), throwsA(isA<MapServiceException>()));
    expect(calls, 2);
  });

  test(
    'OSRM route coordinates, distance and maneuvers are parsed without swapping axes',
    () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'router.project-osrm.org');
        expect(
          request.url.path,
          '/route/v1/driving/105.8542,21.0285;105.86,21.03',
        );
        expect(request.url.queryParameters['steps'], 'true');
        return http.Response(
          jsonEncode({
            'code': 'Ok',
            'routes': [
              {
                'distance': 1200,
                'duration': 300,
                'geometry': {
                  'type': 'LineString',
                  'coordinates': [
                    [105.8542, 21.0285],
                    [105.86, 21.03],
                  ],
                },
                'legs': [
                  {
                    'steps': [
                      {
                        'name': 'Đường thử nghiệm',
                        'distance': 100,
                        'maneuver': {'type': 'turn', 'modifier': 'right'},
                      },
                    ],
                  },
                ],
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      addTearDown(client.close);
      final route = await OsmMapRepository(
        client,
      ).route(const GeoPoint(21.0285, 105.8542), const GeoPoint(21.03, 105.86));
      expect(route.points.first.latitude, 21.0285);
      expect(route.points.last.longitude, 105.86);
      expect(route.distanceMeters, 1200);
      expect(route.durationSeconds, 300);
      expect(route.steps.single.instruction, 'Rẽ phải vào Đường thử nghiệm');
    },
  );

  test('routing rejects no-route results and malformed geometry', () async {
    var body = {'code': 'NoRoute', 'routes': <Object>[]};
    final client = MockClient(
      (_) async => http.Response(jsonEncode(body), 200),
    );
    addTearDown(client.close);
    final repo = OsmMapRepository(client);
    await expectLater(
      repo.route(const GeoPoint(21, 105), const GeoPoint(22, 106)),
      throwsA(isA<MapServiceException>()),
    );
    body = {
      'code': 'Ok',
      'routes': [
        {
          'distance': 1,
          'duration': 1,
          'geometry': {
            'coordinates': [
              [105, 21],
              [999, 22],
            ],
          },
          'legs': [],
        },
      ],
    };
    await expectLater(
      repo.route(const GeoPoint(21, 105), const GeoPoint(22, 106)),
      throwsFormatException,
    );
  });

  test(
    'Overpass keeps node positions, way centers and raw tags, with a bounded cache',
    () async {
      var now = DateTime.utc(2026, 10, 30);
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        final query = request.url.queryParameters['data']!;
        expect(query, contains('around:1000,'));
        expect(query, contains('out body center 80;'));
        return http.Response(
          jsonEncode({
            'elements': [
              {
                'type': 'node',
                'id': 1,
                'lat': 21.0001,
                'lon': 105,
                'tags': {'traffic_sign': 'VN:P.102'},
              },
              {
                'type': 'way',
                'id': 2,
                'center': {'lat': 21.0002, 'lon': 105},
                'tags': {'maxspeed': '50', 'name': 'Đường thử nghiệm'},
              },
              {
                'type': 'node',
                'id': 3,
                'tags': {'traffic_sign': 'bad'},
              },
              {
                'type': 'node',
                'id': 4,
                'lat': 23,
                'lon': 107,
                'tags': {'traffic_sign': 'far'},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      addTearDown(client.close);
      final repo = OsmMapRepository(client, now: () => now);
      final snapshot = await repo.traffic(const GeoPoint(21, 105));
      expect(snapshot.features.length, 3);
      final nearby = snapshot.nearby(const GeoPoint(21, 105));
      expect(nearby.length, 2);
      expect(nearby.first.id, 'node/1');
      expect(nearby.last.isSpeedTag, isTrue);
      expect(nearby.last.label, contains('maxspeed: 50'));
      expect(await repo.traffic(const GeoPoint(21, 105)), same(snapshot));
      expect(calls, 1);
      now = now.add(const Duration(minutes: 3));
      await repo.traffic(const GeoPoint(21, 105));
      expect(calls, 2);
    },
  );

  test(
    'HTTP failures and Overpass timeout remarks are not presented as missing signs',
    () async {
      var status = 503;
      var body = '{}';
      final client = MockClient((_) async => http.Response(body, status));
      addTearDown(client.close);
      final repo = OsmMapRepository(client);
      await expectLater(
        repo.traffic(const GeoPoint(21, 105)),
        throwsA(isA<MapServiceException>()),
      );
      status = 200;
      body = jsonEncode({'remark': 'runtime timeout', 'elements': []});
      await expectLater(
        repo.traffic(const GeoPoint(21, 105)),
        throwsA(isA<MapServiceException>()),
      );
    },
  );
}
