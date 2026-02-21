import 'dart:math';

class FareCalculator {

  static double calculateDistance(
      double lat1,
      double lon1,
      double lat2,
      double lon2) {

    const R = 6371; // Earth radius in KM

    double dLat = _degToRad(lat2 - lat1);
    double dLon = _degToRad(lon2 - lon1);

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }

  static double _degToRad(double deg) =>
      deg * pi / 180;

  static double calculateFare(double distanceKm) {

    double baseFare = 40;
    double perKmRate = 15;
    double perMinRate = 2;

    double estimatedMinutes = distanceKm * 3;

    return baseFare +
        (distanceKm * perKmRate) +
        (estimatedMinutes * perMinRate);
  }
}