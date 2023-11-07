import 'dart:convert';
import 'dart:async';

import 'package:digital_scale/digital_scale.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:roundabnt/round_abnt.dart';

class DigitalScale implements DigitalScaleImplementation {
  final String digitalScalePort;
  final String digitalScaleModel;
  final int digitalScaleRate;
  final int digitalScaleTimeout;
  static late SerialPort serialPort;
  static late SerialPortReader serialPortReader;
  static int factor = 1;
  static String initString = '';

  /// initialize the serial port and call methods
  DigitalScale(
      {required this.digitalScalePort,
      required this.digitalScaleModel,
      required this.digitalScaleRate,
      required this.digitalScaleTimeout,}) {
    serialPort = SerialPort(digitalScalePort);

    bool resp = open();

    if (resp) {
      try {
        config();
        writeInPort(initString);
        readPort();
      } catch (_) {}
    }
  }

  /// Open the port for Read and Write
  @override
  bool open() {
    if (serialPort.isOpen) {
      try {
        serialPort.close();
      } catch (_) {}
    }

    if (!serialPort.isOpen) {
      if (!serialPort.openReadWrite()) {
        return false;
      }
    }

    return true;
  }

  /// Configure the port with arguments
  @override
  config() {
    int stopBits;
    int bits;
    int parity;

    switch (digitalScaleModel.toLowerCase()) {
      case 'toledo prix 3':
        initString = String.fromCharCode(5) + String.fromCharCode(13);
        factor = 1000;
        stopBits = 1;
        bits = 8;
        parity = 0;
        break;
      case 'urano pop light':
        initString = String.fromCharCode(5) +
            String.fromCharCode(10) +
            String.fromCharCode(13);
        factor = 1;
        stopBits = 2;
        bits = 8;
        parity = 0;
        break;
      case 'elgin dp1502':
      default:
        initString = String.fromCharCode(5) +
            String.fromCharCode(10) +
            String.fromCharCode(13);
        factor = 1;
        stopBits = 1;
        bits = 8;
        parity = 0;
    }

    SerialPortConfig config = serialPort.config;
    config.baudRate = digitalScaleRate;
    config.stopBits = stopBits;
    config.bits = bits;
    config.parity = parity;
    serialPort.config = config;
  }

  /// write enq in port
  @override
  writeInPort(String value) {
    try {
      serialPort.write(utf8.encoder.convert(value));
    } catch (_) {}
  }

  /// read the port
  @override
  readPort() {
    try {
      serialPortReader = SerialPortReader(serialPort);
    } catch (_) {}
  }

  /// create the listener and return the weight
  @override
  Future<double> getWeight() async {
    RoundAbnt roundAbnt = RoundAbnt();
    Map<String, ValueNotifier<double>> mapData = {};
    var completer = Completer<double>();
    String decodedWeight = '';
    StreamSubscription? subscription;

    try {
      double weight = 0.00;
      subscription = serialPortReader.stream.listen((data) async {
        decodedWeight += utf8.decode(data);

        if (digitalScaleModel.toLowerCase() == 'urano pop light') {
          decodedWeight = decodedWeight
              .replaceAll('N0', '')
              .replaceAll('kg', '')
              .replaceAll(',', '.')
              .trim();
        } else {
          decodedWeight = decodedWeight
              .replaceAll(RegExp(r'[^\d.]'), '');
        }

        if (decodedWeight.length == 5) {
          weight = ((double.parse(decodedWeight)) / factor);
          weight = roundAbnt.roundAbnt('$weight', 3);

          mapData['weight'] = ValueNotifier<double>(weight);

          completer.complete(mapData['weight']?.value);
          subscription?.cancel();
        }
      });

      await Future.any([
        completer.future,
        Future.delayed(Duration(milliseconds: digitalScaleTimeout))
      ]);

      serialPort.close();
      return weight;
    } catch (e) {
      if (kDebugMode) print('digital scale error: $e');
      serialPort.close();
      subscription?.cancel();
      return -99.99;
    }
  }
}
