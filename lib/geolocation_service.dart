import 'package:geolocator/geolocator.dart';

class GeolocationService {
  /// Returns the current position or `null` if unavailable. This method
  /// is defensive: on any error (including when running tests without
  /// platform bindings) it returns null rather than throwing.
  Future<Position?> getCurrentPosition() async {
    try {
      // 1. Check & request permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return null;
      }

      // 2. Ensure location services are enabled
      if (!(await Geolocator.isLocationServiceEnabled())) {
        return null;
      }

      // 3. Fetch position
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      // In tests or unsupported environments Geolocator may throw because
      // platform bindings aren't initialized; treat that as "no position".
      // ignore: avoid_print
      print('Geolocation error (treated as no position): $e');
      return null;
    }
  }
}
