import 'dart:convert';

import 'package:location/location.dart';

class LocationToJsonConverter {

  String convert(LocationData input) {
    return "{\"latitude\":${input.latitude},\"longitude\":${input.longitude}}";
  }

}

class JsonToLocationConverter {

  LocationData convert(String input) {
    Map<String, dynamic> jsonInput = jsonDecode(input);
    return LocationData.fromMap({
      'latitude':jsonInput['latitude'],
      'longitude':jsonInput['longitude'],
    });
  }

}