
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:logger/logger.dart';
import '../utils/constants.dart';
import '../utils/enums.dart';

class MqttService {
  final Logger _logger = Logger();
  MqttServerClient? _client;
  
  final _controller = StreamController<MqttConnectionStatus>.broadcast();
  Stream<MqttConnectionStatus> get statusStream => _controller.stream;
  
  MqttConnectionStatus _currentStatus = MqttConnectionStatus.disconnected;
  MqttConnectionStatus get currentStatus => _currentStatus;

  // Connection parameters
  final String _broker = AppConstants.mqttBroker;
  final int _port = AppConstants.mqttPort;
  final String _clientIdentifier = AppConstants.mqttClientIdentifier;
  final String _username = AppConstants.mqttUsername;
  final String _password = AppConstants.mqttPassword;

  Future<void> connect() async {
    if (_currentStatus == MqttConnectionStatus.connected) return;

    _updateStatus(MqttConnectionStatus.connecting);

    _client = MqttServerClient.withPort(_broker, _clientIdentifier, _port);
    _client!.secure = true;
    _client!.securityContext = SecurityContext.defaultContext;
    _client!.logging(on: false);
    _client!.keepAlivePeriod = AppConstants.mqttKeepAlive;
    _client!.onDisconnected = _onDisconnected;
    _client!.onConnected = _onConnected;
    _client!.onSubscribed = _onSubscribed;
    _client!.onSubscribeFail = _onSubscribeFail;

    final connMess = MqttConnectMessage()
        .withClientIdentifier(_clientIdentifier)
        .withWillTopic('willtopic')
        .withWillMessage('My Will message')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    
    _client!.connectionMessage = connMess;

    try {
      _logger.i('Connecting to MQTT broker...');
      await _client!.connect(_username, _password);
    } catch (e) {
      _logger.e('Exception during MQTT connection: $e');
      _terminate();
      _updateStatus(MqttConnectionStatus.error);
    }
  }

  void _onConnected() {
    _logger.i('MQTT Connected');
    _updateStatus(MqttConnectionStatus.connected);
  }

  void _onDisconnected() {
    _logger.i('MQTT Disconnected');
    if (_client?.connectionStatus?.returnCode == MqttConnectReturnCode.noneSpecified) {
      _logger.i('OnDisconnected callback is solicited, this is correct');
    }
    _updateStatus(MqttConnectionStatus.disconnected);
  }

  void _onSubscribed(String topic) {
    _logger.i('Subscription confirmed for topic $topic');
  }

  void _onSubscribeFail(String topic) {
    _logger.e('Failed to subscribe to topic $topic');
  }

  void _updateStatus(MqttConnectionStatus status) {
    _currentStatus = status;
    _controller.add(status);
  }

  void _terminate() {
    _client?.disconnect();
  }

  Future<void> dispense(int slotNumber) async {
    if (_currentStatus != MqttConnectionStatus.connected) {
      throw Exception('MQTT is not connected');
    }

    final builder = MqttClientPayloadBuilder();
    final msg = jsonEncode({
      'command': 'DISPENSE',
      'slot': slotNumber
    });
    
    builder.addString(msg);
    
    try {
      _logger.i('Publishing dispense command to ${AppConstants.mqttTopicCmd}');
      _client!.publishMessage(
        AppConstants.mqttTopicCmd,
        MqttQos.atLeastOnce,
        builder.payload!
      );
    } catch (e) {
      _logger.e('Error publishing dispense message: $e');
      throw Exception('Failed to send dispense command: $e');
    }
  }

  void dispose() {
    _terminate();
    _controller.close();
  }
}
