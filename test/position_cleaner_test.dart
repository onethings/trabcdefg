import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/src/utils/position_cleaner.dart';

/// Real Valhalla trip answer for the two anchors used below, captured from a live
/// server (polyline6, latitude first). Replaying the actual bytes keeps the
/// decoder honest against what the service really sends.
const String _routeBody = r'''{"trip":{"locations":[{"type":"break","lat":52.5202,"lon":13.405,"date_time":"2023-11-14T23:13","original_index":0},{"type":"break","lat":52.5223,"lon":13.409,"date_time":"2023-11-14T23:14","original_index":1}],"legs":[{"maneuvers":[{"type":1,"instruction":"Drive northeast on Karl-Liebknecht-Straße","begin_shape_index":0,"end_shape_index":13}],"summary":{"time":49.54,"length":0.357},"shape":"iiqdcBu|dqXiAeC_@_AyJ}VyKiXm@yA}F}Ls`@uaAg^i}@aDiI{D{JyEkLaC{FkCsG"}]}}''';

/// The captured leg has 14 vertices, so a spliced gap adds 12 points.
const int _insertedPerGap = 12;

final DateTime _start = DateTime.utc(2023, 11, 14, 22, 13, 20);
final DateTime _end = DateTime.utc(2023, 11, 14, 22, 14, 20);

api.Position _position(double lat, double lon, DateTime time, {num? speed}) => api.Position(latitude: lat, longitude: lon, fixTime: time, deviceTime: time, speed: speed, valid: true);

MockClient _server({void Function(http.Request request)? onRequest}) => MockClient((request) async {
  onRequest?.call(request);
  return http.Response(_routeBody, 200);
});

void main() {
  group('PositionCleaner.fillStraightGaps', () {
    test('splices road geometry into a long gap and keeps the anchors', () async {
      final simplified = [_position(52.52020, 13.40500, _start), _position(52.52230, 13.40900, _end)];
      final result = await PositionCleaner.fillStraightGaps(simplified, routeUrl: 'https://valhalla.example/route', client: _server());

      expect(result.length, simplified.length + _insertedPerGap);
      expect(identical(result.first, simplified.first), isTrue);
      expect(identical(result.last, simplified.last), isTrue);

      final inserted = result.sublist(1, result.length - 1);
      for (final point in inserted) {
        // Latitude first: a swapped decoder would put Berlin's latitude at 13.4°
        // and its longitude at 52.5°.
        expect(point.latitude!.toDouble(), inInclusiveRange(52.5199, 52.5226));
        expect(point.longitude!.toDouble(), inInclusiveRange(13.4049, 13.4091));
        // The anchors carried no speed, so the derived one has to be positive or
        // the playback track (which filters on speed > 0) would drop these points.
        expect(point.speed!.toDouble(), greaterThan(0));
      }

      final times = result.map(PositionCleaner.recordingTime).toList();
      for (var i = 1; i < times.length; i++) {
        expect(times[i]!.isBefore(times[i - 1]!), isFalse, reason: 'spliced times must stay monotonic');
      }
      expect(times.first, _start);
      expect(times.last, _end);
    });

    test('keeps a short gap off the network', () async {
      var requests = 0;
      final simplified = [_position(52.52020, 13.40500, _start), _position(52.52050, 13.40530, _end)];
      final result = await PositionCleaner.fillStraightGaps(
        simplified,
        routeUrl: 'https://valhalla.example/route',
        client: _server(onRequest: (_) => requests++),
      );

      expect(requests, 0);
      expect(identical(result, simplified), isTrue);
    });

    test('keeps gaps longer than maxGapMeters off the network', () async {
      var requests = 0;
      // ~29 km apart: past the 20 km ceiling, so this one stays a straight line.
      final simplified = [_position(21.581917, 96.319083, _start), _position(21.75, 96.10, _end)];
      final result = await PositionCleaner.fillStraightGaps(
        simplified,
        routeUrl: 'https://valhalla.example/route',
        client: _server(onRequest: (_) => requests++),
      );

      expect(requests, 0);
      expect(identical(result, simplified), isTrue);
    });

    test('falls back to the drawn line when the server rejects the request', () async {
      final simplified = [_position(52.52020, 13.40500, _start), _position(52.52230, 13.40900, _end)];
      final result = await PositionCleaner.fillStraightGaps(
        simplified,
        routeUrl: 'https://valhalla.example/route',
        client: MockClient((request) async => http.Response('{"error_code":171,"error":"No path could be found","status_code":400}', 400)),
      );

      expect(identical(result, simplified), isTrue);
    });

    test('an empty endpoint disables gap filling entirely', () async {
      var requests = 0;
      final simplified = [_position(52.52020, 13.40500, _start), _position(52.52230, 13.40900, _end)];
      final result = await PositionCleaner.fillStraightGaps(
        simplified,
        routeUrl: '',
        client: _server(onRequest: (_) => requests++),
      );

      expect(requests, 0);
      expect(identical(result, simplified), isTrue);
    });

    test('leaves untouched vertices in place and ends on the real last sample', () async {
      final simplified = [_position(52.52020, 13.40500, _start), _position(52.52025, 13.40505, _start.add(const Duration(seconds: 5))), _position(52.52230, 13.40900, _end)];
      final result = await PositionCleaner.fillStraightGaps(simplified, routeUrl: 'https://valhalla.example/route', client: _server());

      expect(identical(result[0], simplified[0]), isTrue);
      expect(identical(result[1], simplified[1]), isTrue);
      expect(identical(result.last, simplified.last), isTrue);
      expect(result.length, simplified.length + _insertedPerGap);
    });

    test('keeps every untouched vertex when more than one gap is spliced', () async {
      // A → B is a gap, B → C is a short hop, C → D is another gap. The short hop
      // in the middle is the one a splice-everything-but-copy-nothing bug eats.
      final simplified = [
        _position(52.52020, 13.40500, _start),
        _position(52.52230, 13.40900, _start.add(const Duration(seconds: 30))),
        _position(52.52235, 13.40905, _start.add(const Duration(seconds: 35))),
        _position(52.52440, 13.41300, _end),
      ];
      final result = await PositionCleaner.fillStraightGaps(simplified, routeUrl: 'https://valhalla.example/route', client: _server());

      var previousIndex = -1;
      for (var i = 0; i < simplified.length; i++) {
        final index = result.indexWhere((point) => identical(point, simplified[i]));
        expect(index, greaterThan(previousIndex), reason: 'vertex $i must survive, in order');
        previousIndex = index;
      }
      expect(result.length, simplified.length + 2 * _insertedPerGap);
    });

    test('asks for a route between the two anchors', () async {
      http.Request? sent;
      final simplified = [_position(52.52020, 13.40500, _start), _position(52.52230, 13.40900, _end)];
      await PositionCleaner.fillStraightGaps(
        simplified,
        routeUrl: 'https://valhalla.example/route',
        client: _server(onRequest: (request) => sent = request),
      );

      expect(sent!.url.path, '/route');
      final body = jsonDecode(sent!.body) as Map<String, dynamic>;
      final locations = (body['locations'] as List).cast<Map<String, dynamic>>();
      expect(locations, hasLength(2));
      expect(locations.first['lat'], 52.52020);
      expect(locations.first['lon'], 13.40500);
      expect(locations.first['radius'], isA<num>());
      expect(body['costing'], 'auto');
    });

    test('spends the request budget on the longest gaps first', () async {
      // Three gaps of 250 m-ish, ~1.2 km and ~4 km: with a budget of one request
      // only the longest may be routed, because that is the chord that hurts most.
      final simplified = [
        _position(52.52000, 13.40500, _start),
        _position(52.52230, 13.40900, _start.add(const Duration(seconds: 20))), // ~340 m
        _position(52.53300, 13.42900, _start.add(const Duration(seconds: 400))), // ~1.8 km
        _position(52.55500, 13.46900, _end), // ~4.4 km
      ];
      final sentGaps = <String>[];
      await PositionCleaner.fillStraightGaps(
        simplified,
        routeUrl: 'https://valhalla.example/route',
        maxRequests: 1,
        client: _server(
          onRequest: (request) {
            final locations = (jsonDecode(request.body) as Map<String, dynamic>)['locations'] as List;
            final first = locations.first as Map<String, dynamic>;
            sentGaps.add('${first['lat']},${first['lon']}');
          },
        ),
      );

      expect(sentGaps, hasLength(1));
      expect(sentGaps.single, '52.533,13.429', reason: 'the 4.4 km gap must be the one routed');
    });
  });
}
