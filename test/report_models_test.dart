import 'package:flutter_test/flutter_test.dart';
import 'package:trabcdefg/screens/reports/geofences_report_screen.dart';
import 'package:trabcdefg/screens/reports/stops_report_screen.dart';
import 'package:trabcdefg/screens/reports/trips_report_screen.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

void main() {
  test('TripReport.fromJson defaults every missing field', () {
    final trip = TripReport.fromJson({'deviceId': 7});

    expect(trip.deviceId, 7);
    expect(trip.deviceName, '');
    expect(trip.distance, 0);
    expect(trip.averageSpeed, 0);
    expect(trip.maxSpeed, 0);
    expect(trip.duration, 0);
    expect(trip.startTime, DateTime.fromMillisecondsSinceEpoch(0));
    expect(trip.startAddress, isNull);
    expect(trip.driverName, isNull);
  });

  test('TripReport.fromJson converts knots to km/h', () {
    final trip = TripReport.fromJson({'averageSpeed': 10, 'maxSpeed': 1});

    expect(trip.averageSpeed, closeTo(18.52, 1e-9));
    expect(trip.maxSpeed, closeTo(1.852, 1e-9));
  });

  test('TripReport.fromJson keeps a bad timestamp out of the parse path', () {
    final trip = TripReport.fromJson({'startTime': 'not-a-date'});

    expect(trip.startTime, DateTime.fromMillisecondsSinceEpoch(0));
  });

  test('StopReport.fromJson defaults every missing field', () {
    final stop = StopReport.fromJson({'deviceName': 'van'});

    expect(stop.deviceId, 0);
    expect(stop.deviceName, 'van');
    expect(stop.latitude, 0);
    expect(stop.longitude, 0);
    expect(stop.duration, 0);
    expect(stop.engineHours, isNull);
    expect(stop.endTime, DateTime.fromMillisecondsSinceEpoch(0));
  });

  test('StopReport.fromJson keeps engineHours when the server sends it', () {
    final stop = StopReport.fromJson({'engineHours': 3, 'duration': 120});

    expect(stop.engineHours, 3);
    expect(stop.duration, 120);
  });

  test('GeofenceItem.fromApi tolerates a partial server payload', () {
    final item = GeofenceItem.fromApi(api.ReportGeofences());

    expect(item.deviceId, 0);
    expect(item.geofenceId, 0);
    expect(item.deviceName, '');
    expect(item.endTime, item.startTime);
  });

  test('GeofenceItem.fromApi keeps the server interval', () {
    final start = DateTime.utc(2024, 5, 1, 8);
    final end = DateTime.utc(2024, 5, 1, 9);
    final item = GeofenceItem.fromApi(
      api.ReportGeofences(deviceId: 2, geofenceId: 9, startTime: start, endTime: end),
    );

    expect(item.duration, const Duration(hours: 1));
  });
}
