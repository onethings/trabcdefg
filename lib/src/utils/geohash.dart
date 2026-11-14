// lib/src/utils/geohash.dart
//
// Geohash encode / decode, kept in-repo so the offline address service does not
// need a package for it.
//
// Both directions follow the reference geohash algorithm: the bit stream
// alternates longitude and latitude from the longitude bit, `1` selects the
// upper half of the current interval, and base32 is the standard
// "0123456789bcdefghjkmnpqrstuvwxyz". `decode` returns the centre of the cell,
// which is what the address matcher compares coordinates against.

/// Geohash encode / decode with the reference algorithm's semantics.
class GeoHasher {
  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
  static final RegExp _validPattern = RegExp('^[$_base32]+\$');

  /// Encodes [longitude] and [latitude] into a geohash of [precision] chars.
  ///
  /// Throws [RangeError] for coordinates outside the globe, matching what the
  /// service previously relied on so a bad coordinate still surfaces loudly.
  String encode(double longitude, double latitude, {int precision = 12}) {
    if (longitude < -180.0 || longitude > 180.0) {
      throw RangeError.range(longitude, -180, 180, 'Longitude');
    }
    if (latitude < -90.0 || latitude > 90.0) {
      throw RangeError.range(latitude, -90, 90, 'Latitude');
    }
    if (precision < 1) {
      throw RangeError.range(precision, 1, null, 'precision');
    }

    var latLower = -90.0;
    var latUpper = 90.0;
    var lonLower = -180.0;
    var lonUpper = 180.0;

    final StringBuffer result = StringBuffer();
    var bits = 0;
    var bitCount = 0;
    var isLongitude = true;

    while (result.length < precision) {
      if (isLongitude) {
        final double middle = (lonLower + lonUpper) / 2;
        if (longitude >= middle) {
          bits = (bits << 1) | 1;
          lonLower = middle;
        } else {
          bits <<= 1;
          lonUpper = middle;
        }
      } else {
        final double middle = (latLower + latUpper) / 2;
        if (latitude >= middle) {
          bits = (bits << 1) | 1;
          latLower = middle;
        } else {
          bits <<= 1;
          latUpper = middle;
        }
      }
      isLongitude = !isLongitude;

      if (++bitCount == 5) {
        result.write(_base32[bits]);
        bits = 0;
        bitCount = 0;
      }
    }

    return result.toString();
  }

  /// Decodes [geohash] into `[longitude, latitude]` of the cell centre.
  ///
  /// Throws [ArgumentError] on an empty or malformed geohash.
  List<double> decode(String geohash) {
    if (geohash.isEmpty) {
      throw ArgumentError.value(geohash, 'geohash', 'GeoHash is empty');
    }
    if (!_validPattern.hasMatch(geohash)) {
      throw ArgumentError.value(geohash, 'geohash', 'Invalid character in GeoHash');
    }

    var latLower = -90.0;
    var latUpper = 90.0;
    var lonLower = -180.0;
    var lonUpper = 180.0;
    var isLongitude = true;

    for (final String character in geohash.split('')) {
      final int value = _base32.indexOf(character);
      for (var mask = 16; mask >= 1; mask >>= 1) {
        final bool upperHalf = (value & mask) != 0;
        if (isLongitude) {
          final double middle = (lonLower + lonUpper) / 2;
          if (upperHalf) {
            lonLower = middle;
          } else {
            lonUpper = middle;
          }
        } else {
          final double middle = (latLower + latUpper) / 2;
          if (upperHalf) {
            latLower = middle;
          } else {
            latUpper = middle;
          }
        }
        isLongitude = !isLongitude;
      }
    }

    return [(lonLower + lonUpper) / 2, (latLower + latUpper) / 2];
  }
}
