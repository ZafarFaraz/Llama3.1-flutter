import 'package:geocoding/geocoding.dart';
import 'package:location/location.dart' as loc;

class LocationService {
  String? _locationAddress;

  Future<String?> fetchAndStoreLocation() async {
    loc.Location location = loc.Location(); // Use the alias here
    bool _serviceEnabled;
    loc.PermissionStatus _permissionGranted;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return null;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == loc.PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != loc.PermissionStatus.granted) {
        return null;
      }
    }

    loc.LocationData locationData = await location.getLocation();

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        locationData.latitude!,
        locationData.longitude!,
      );

      Placemark place = placemarks[0];
      _locationAddress =
          "${place.locality}, ${place.postalCode}, ${place.country}";
      return _locationAddress;
    } catch (e) {
      print('Failed to get address: $e');
      return 'Address unavailable';
    }
  }
}
