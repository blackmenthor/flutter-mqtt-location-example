import 'package:location/location.dart';

class LocationWrapper {

  var location = new Location();
  final Function(LocationData) onLocationChanged;

  LocationWrapper(this.onLocationChanged);

  void prepareLocationMonitoring() {
    location.hasPermission().then((bool hasPermission) {
      if (!hasPermission) {
        location.requestPermission().then((bool permissionGranted) {
          if (permissionGranted) {
            _subscribeToLocation();
          }
        });
      } else {
        _subscribeToLocation();
      }
    });
  }

  void _subscribeToLocation() {
    location.onLocationChanged().listen((LocationData newLocation) {
      onLocationChanged(newLocation);
    });
  }

}