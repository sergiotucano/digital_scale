import 'dart:convert';
import 'dart:async';

import 'package:digital_scale/digital_scale.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:roundabnt/round_abnt.dart';

class DigitalScale implements DigitalScaleImplementation {
  final String digitalScalePort;
  final String digitalScaleModel;
  static late SerialPort serialPort;
  static late SerialPortReader serialPortReader;
  static int factor = 1;
  static int timeout = 5000;
  static String initString = '';

  /// initialize the serial port and call methods
  DigitalScale(this.digitalScalePort, this.digitalScaleModel) {
    serialPort = SerialPort(digitalScalePort);

    bool resp = open();

    if (resp) {
      config();
      writeInPort(initString);
      readPort();
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
    int baundRate;
    int stopBits;
    int bits;
    int parity;

    switch (digitalScaleModel.toLowerCase()) {
      case 'toledo prix 3':
        initString = String.fromCharCode(5) + String.fromCharCode(13);
        factor = 1000;
        timeout = 2500;
        baundRate = 115200;
        stopBits = 1;
        bits = 8;
        parity = 0;
        break;
      case 'urano pop light':
        initString = String.fromCharCode(5) +
            String.fromCharCode(10) +
            String.fromCharCode(13);
        factor = 1;
        timeout = 2000;
        baundRate = 9600;
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
        timeout = 6000;
        baundRate = 2400;
        stopBits = 1;
        bits = 8;
        parity = 0;
    }

    SerialPortConfig config = serialPort.config;
    config.baudRate = baundRate;
    config.stopBits = stopBits;
    config.bits = bits;
    config.parity = parity;
    serialPort.config = config;
  }

  /// write enq in port
  @override
  writeInPort(String value) {
    serialPort.write(utf8.encoder.convert(value));
  }

  /// read the port
  @override
  readPort() {
    serialPortReader = SerialPortReader(serialPort);
  }

  /// create the listener and return the weight
  @override
  Future<double> getWeight() async {
    RoundAbnt roundAbnt = RoundAbnt();
    var completer = Completer<double>();
    Map<String, ValueNotifier<double>> mapData = {};

    try {
      double weight = 0.00;
      serialPortReader.stream.listen((data) async {
        final String decodedWeight = utf8.decode(data);
        String weightStr = '0.00';

        if (digitalScaleModel.toLowerCase() == 'urano pop light') {
          weightStr = decodedWeight
              .substring(decodedWeight.indexOf('N0') + 2,
                  (decodedWeight.indexOf('kg') - 1))
              .trim()
              .replaceAll(',', '.');
        } else {
          weightStr =
              decodedWeight.substring(1, (decodedWeight.length - 1)).trim();
        }

        completer.complete(mapData['weight']?.value);

        weight = ((double.parse(weightStr)) / factor);
        weight = roundAbnt.roundAbnt('$weight', 3);

        mapData['weight'] = ValueNotifier<double>(weight);

        completer.future;
      });

      await Future.delayed(Duration(milliseconds: timeout), () {
        serialPort.close();
        return weight;
      });

      return weight;
    } catch (_) {
      return -99.99;
    }
  }
}
