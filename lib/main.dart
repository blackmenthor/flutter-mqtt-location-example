import 'package:flutter/material.dart';
import 'package:flutter_mqtt_location_example/locationWrapper.dart';
import 'package:flutter_mqtt_location_example/mqttClientWrapper.dart';
import 'package:flutter_mqtt_location_example/models.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:flutter_mqtt_location_example/constants.dart' as Constants;

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter MQTT Location Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter MQTT Location'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  MQTTClientWrapper mqttClientWrapper;
  LocationWrapper locationWrapper;

  LocationData currentLocation;

  GoogleMapController _controller;

  void setup() {
    locationWrapper = LocationWrapper((newLocation) => mqttClientWrapper.publishLocation(newLocation));
    mqttClientWrapper = MQTTClientWrapper(
            () => locationWrapper.prepareLocationMonitoring(),
            (newLocationJson) => gotNewLocation(newLocationJson)
    );
    mqttClientWrapper.prepareMqttClient();
  }

  void gotNewLocation(LocationData newLocationData) {
    setState(() {
      this.currentLocation = newLocationData;
    });
    animateCameraToNewLocation(newLocationData);
  }

  void animateCameraToNewLocation(LocationData newLocation) {
    _controller?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: LatLng(
            newLocation.latitude,
            newLocation.longitude
        ),
        zoom: Constants.newZoom
    )));
  }

  @override
  void initState() {
    super.initState();

    setup();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: mqttClientWrapper.connectionState != MqttCurrentConnectionState.CONNECTED ?
      Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text("CONNECTING TO MQTT..."),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: CircularProgressIndicator(),
            ),
          ],
        ),
      ) :
      GoogleMap(
        initialCameraPosition: CameraPosition(
            target: LatLng(Constants.defaultLocation.latitude, Constants.defaultLocation.longitude),
            zoom: Constants.defaultZoom
        ),
        markers: currentLocation == null ? Set() : [
          Marker(
              markerId: MarkerId(Constants.defaultMarkerId),
              position: LatLng(currentLocation.latitude, currentLocation.longitude)
          )
        ].toSet(),
        onMapCreated: (GoogleMapController controller) {
          setState(() {
            this._controller = controller;
          });
        },
      ),
    );
  }
}