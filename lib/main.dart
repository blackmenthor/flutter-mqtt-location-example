import 'package:flutter/material.dart';
import 'package:flutter_mqtt_location_example/converter.dart';
import 'package:flutter_mqtt_location_example/models.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:mqtt_client/mqtt_client.dart';

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

  MqttClient client;
  MqttCurrentConnectionState _connectionState = MqttCurrentConnectionState.IDLE;
  MqttSubscriptionState _subscriptionState = MqttSubscriptionState.IDLE;
  LocationToJsonConverter locationToJsonConverter = LocationToJsonConverter();
  JsonToLocationConverter jsonToLocationConverter = JsonToLocationConverter();

  final String SERVER_URI = "test.mosquitto.org";
  final int PORT = 1883;
  final String TOPIC_NAME = "Dart/Mqtt_client/testtopic";

  double defaultZoom = 10.8746;
  double newZoom = 15.8746;

  LocationData defaultLocation = new LocationData.fromMap({
    'latitude': -6.1753871,
    'longitude': 106.8249641
  });

  LocationData currentLocation;

  var location = new Location();

  GoogleMapController _controller;

  Future<void> prepareMqttClient() async {
    client = MqttClient.withPort(SERVER_URI, '#', PORT);
    client.logging(on: false);
    client.keepAlivePeriod = 20;
    client.onDisconnected = onDisconnected;
    client.onConnected = onConnected;
    client.onSubscribed = onSubscribed;

    try {
      print('EXAMPLE::Mosquitto client connecting....');
      setState(() {
        _connectionState = MqttCurrentConnectionState.CONNECTING;
      });
      await client.connect();
    } on Exception catch (e) {
      print('EXAMPLE::client exception - $e');
      setState(() {
        _connectionState = MqttCurrentConnectionState.ERROR_WHEN_CONNECTING;
      });
      client.disconnect();
    }

    if (client.connectionStatus.state == MqttConnectionState.connected) {
      setState(() {
        _connectionState = MqttCurrentConnectionState.CONNECTED;
      });
      print('EXAMPLE::Mosquitto client connected');
    } else {
      print(
          'EXAMPLE::ERROR Mosquitto client connection failed - disconnecting, status is ${client.connectionStatus}');
      setState(() {
        _connectionState = MqttCurrentConnectionState.ERROR_WHEN_CONNECTING;
      });
      client.disconnect();
    }

    print('EXAMPLE::Subscribing to the $TOPIC_NAME topic');
    client.subscribe(TOPIC_NAME, MqttQos.atMostOnce);

    client.updates.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage recMess = c[0].payload;
      final String newLocationJson =
      MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      print("[ONGGO] GOT A NEW MESSAGE $newLocationJson");
      gotNewLocation(newLocationJson);
    });
  }

  void onSubscribed(String topic) {
    print('EXAMPLE::Subscription confirmed for topic $topic');
    setState(() {
      _subscriptionState = MqttSubscriptionState.SUBSCRIBED;
    });
  }

  void onDisconnected() {
    print('EXAMPLE::OnDisconnected client callback - Client disconnection');
    if (client.connectionStatus.returnCode == MqttConnectReturnCode.solicited) {
      print('EXAMPLE::OnDisconnected callback is solicited, this is correct');
    }
    setState(() {
      _connectionState = MqttCurrentConnectionState.DISCONNECTED;
    });
  }

  void onConnected() {
    setState(() {
      _connectionState = MqttCurrentConnectionState.CONNECTED;
    });
    print(
        'EXAMPLE::OnConnected client callback - Client connection was sucessful');
    prepareLocationMonitoring();
  }

  void publishMessage(String message) {
    final MqttClientPayloadBuilder builder = MqttClientPayloadBuilder();
    builder.addString(message);

    print('EXAMPLE::Publishing message $message to topic $TOPIC_NAME');
    client.publishMessage(TOPIC_NAME, MqttQos.exactlyOnce, builder.payload);
  }

  void publishLocation(LocationData locationData) {
    String locationJson = locationToJsonConverter.convert(locationData);
    publishMessage(locationJson);
  }

  void gotNewLocation(String newLocationJson) {
    try {
      LocationData newLocationData = jsonToLocationConverter.convert(
          newLocationJson);

      setState(() {
        this.currentLocation = newLocationData;
      });
      animateCameraToNewLocation(newLocationData);
    } catch (exception) {
      print("Json can't be formatted ${exception.toString()}");
    }
  }

  void setup() async {
    prepareMqttClient();
  }

  void prepareLocationMonitoring() {
    location.hasPermission().then((bool hasPermission) {
      if (!hasPermission) {
        location.requestPermission().then((bool permissionGranted) {
          if (permissionGranted) {
            subscribeToLocation();
          }
        });
      } else {
        subscribeToLocation();
      }
    });
  }

  void subscribeToLocation() {
    location.onLocationChanged().listen((LocationData newLocation) {
      publishLocation(newLocation);
    });
  }

  void animateCameraToNewLocation(LocationData newLocation) {
    _controller?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: LatLng(
            newLocation.latitude,
            newLocation.longitude
        ),
        zoom: newZoom
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
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
            target: LatLng(defaultLocation.latitude, defaultLocation.longitude),
            zoom: defaultZoom
        ),
        markers: currentLocation == null ? Set() : [
          Marker(
              markerId: MarkerId("1"),
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