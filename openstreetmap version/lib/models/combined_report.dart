// lib/models/combined_report.dart
// Model to represent a combined report of positions and events.
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

class CombinedReport {
	int? deviceId;
	List<List<double>>? route;
	List<api.Event>? events;
	List<api.Position>? positions;

	CombinedReport({this.deviceId, this.route, this.events, this.positions});

	CombinedReport.fromJson(Map<String, dynamic> json) {
		deviceId = json['deviceId'];
		if (json['route'] != null) {
			route = <List<double>>[];
			json['route'].forEach((v) {
        if (v is List && v.isNotEmpty) {
          route!.add(v.cast<double>());
        }
      });
		}
		if (json['events'] != null) {
			events = (json['events'] as List)
          .map((v) => api.Event.fromJson(v))
          .whereType<api.Event>()
          .toList();
		}
		if (json['positions'] != null) {
			positions = (json['positions'] as List)
          .map((v) => api.Position.fromJson(v))
          .whereType<api.Position>()
          .toList();
		}
	}

	Map<String, dynamic> toJson() {
		final Map<String, dynamic> data = <String, dynamic>{};
		data['deviceId'] = deviceId;
		if (route != null) {
      data['route'] = route!.map((v) => v).toList();
    }
		if (events != null) {
      data['events'] = events!.map((v) => v.toJson()).toList();
    }
		if (positions != null) {
      data['positions'] = positions!.map((v) => v.toJson()).toList();
    }
		return data;
	}
}