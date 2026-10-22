import 'package:trabcdefg/src/generated_api/api.dart' as api;

bool hasValidPositionCoordinates(api.Position? position) {
  if (position?.latitude == null || position?.longitude == null) return false;

  final double latitude = position!.latitude!.toDouble();
  final double longitude = position.longitude!.toDouble();
  return latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}
