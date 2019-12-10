import 'package:flutter/material.dart';
import 'package:flutter_mqtt_location_example/converter.dart';
import 'package:flutter_mqtt_location_example/constants.dart' as Constants;
import 'package:location/location.dart';
import 'package:mqtt_client/mqtt_client.dart';

import 'models.dart';

class MQTTClientWrapper {

  MqttClient client;
  LocationToJsonConverter locationToJsonConverter = LocationToJsonConverter();
  JsonToLocationConverter jsonToLocationConverter = JsonToLocationConverter();

  MqttCurrentConnectionState connectionState = MqttCurrentConnectionState.IDLE;
  MqttSubscriptionState subscriptionState = MqttSubscriptionState.IDLE;

  final VoidCallback onConnectedCallback;
  final Function(LocationData) onLocationReceivedCallback;

  MQTTClientWrapper(this.onConnectedCallback, this.onLocationReceivedCallback);

  void prepareMqttClient() async {
    _setupMqttClient();
    await _connectClient();
    _subscribeToTopic(Constants.topicName);
  }

  void publishLocation(LocationData locationData) {
    String locationJson = locationToJsonConverter.convert(locationData);
    _publishMessage(locationJson);
  }

  Future<void> _connectClient() async {
    try {
      print('MQTTClientWrapper::Mosquitto client connecting....');
      connectionState = MqttCurrentConnectionState.CONNECTING;
      await client.connect();
    } on Exception catch (e) {
      print('MQTTClientWrapper::client exception - $e');
      connectionState = MqttCurrentConnectionState.ERROR_WHEN_CONNECTING;
      client.disconnect();
    }

    if (client.connectionStatus.state == MqttConnectionState.connected) {
      connectionState = MqttCurrentConnectionState.CONNECTED;
      print('MQTTClientWrapper::Mosquitto client connected');
    } else {
      print(
          'MQTTClientWrapper::ERROR Mosquitto client connection failed - disconnecting, status is ${client.connectionStatus}');
      connectionState = MqttCurrentConnectionState.ERROR_WHEN_CONNECTING;
      client.disconnect();
    }
  }

  void _setupMqttClient() {
    client = MqttClient.withPort(Constants.serverUri, '#', Constants.port);
    client.logging(on: false);
    client.keepAlivePeriod = 20;
    client.onDisconnected = _onDisconnected;
    client.onConnected = _onConnected;
    client.onSubscribed = _onSubscribed;
  }

  void _subscribeToTopic(String topicName) {
    print('MQTTClientWrapper::Subscribing to the $topicName topic');
    client.subscribe(topicName, MqttQos.atMostOnce);

    client.updates.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage recMess = c[0].payload;
      final String newLocationJson =
      MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      print("MQTTClientWrapper::GOT A NEW MESSAGE $newLocationJson");
      LocationData newLocationData = _convertJsonToLocation(newLocationJson);
      if (newLocationData != null) onLocationReceivedCallback(newLocationData);
    });
  }

  LocationData _convertJsonToLocation(String newLocationJson) {
    try {
      return jsonToLocationConverter.convert(
          newLocationJson);
    } catch (exception) {
      print("Json can't be formatted ${exception.toString()}");
    }
    return null;
  }

  void _publishMessage(String message) {
    final MqttClientPayloadBuilder builder = MqttClientPayloadBuilder();
    builder.addString(message);

    print('MQTTClientWrapper::Publishing message $message to topic ${Constants.topicName}');
    client.publishMessage(Constants.topicName, MqttQos.exactlyOnce, builder.payload);
  }

  void _onSubscribed(String topic) {
    print('MQTTClientWrapper::Subscription confirmed for topic $topic');
    subscriptionState = MqttSubscriptionState.SUBSCRIBED;
  }

  void _onDisconnected() {
    print('MQTTClientWrapper::OnDisconnected client callback - Client disconnection');
    if (client.connectionStatus.returnCode == MqttConnectReturnCode.solicited) {
      print('MQTTClientWrapper::OnDisconnected callback is solicited, this is correct');
    }
    connectionState = MqttCurrentConnectionState.DISCONNECTED;
  }

  void _onConnected() {
    connectionState = MqttCurrentConnectionState.CONNECTED;
    print(
        'MQTTClientWrapper::OnConnected client callback - Client connection was sucessful');
    onConnectedCallback();
  }

}