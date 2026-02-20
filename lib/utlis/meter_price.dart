import 'dart:math';


class PuneFareCalculator {
  static const double autoBaseFare = 26.0;
  static const double autoPerKmRate = 17.14;


  static const double cabBaseFare = 37.0;
  static const double cabPerKmRate = 25.00;


  static const double baseDistanceKm = 1.5;


  static int calculateFare({
    required double distance,
    required bool isAuto,
    bool isNight = false,
    bool isAc = false,
    double waitingTimeMinutes = 0,
  }) {
    double baseFare = isAuto ? autoBaseFare : cabBaseFare;
    double perKmRate = isAuto ? autoPerKmRate : cabPerKmRate;


    double totalFare;


    if (distance <= baseDistanceKm) {
      totalFare = baseFare;
    } else {
      totalFare = baseFare + (distance - baseDistanceKm) * perKmRate;
    }


    if (isAuto && waitingTimeMinutes > 5) {
      totalFare += (waitingTimeMinutes - 5);
    }


    if (isAc && !isAuto) {
      totalFare *= 1.10;
    }


    if (isNight) {
      totalFare *= 1.25;
    }


    return totalFare.round();
  }


  static bool isNightTime() {
    final hour = DateTime.now().hour;
    return hour >= 0 && hour < 5;
  }
}





