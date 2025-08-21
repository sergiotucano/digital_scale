import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:digital_scale/digital_scale.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:roundabnt/roundabnt.dart';

class DigitalScale implements DigitalScaleImplementation {
  final String digitalScalePort;
  final String digitalScaleModel;
  final int digitalScaleRate;
  final int digitalScaleTimeout;
  static late SerialPort serialPort;
  static late SerialPortReader serialPortReader;
  static int factor = 1;
  static String initString = '';
  final bool digitalScaleBt;
  final bool continuosRead;
  static late BluetoothConnection connectionBt;

  /// initialize the serial port and call methods
  DigitalScale({
    required this.digitalScalePort,
    required this.digitalScaleModel,
    required this.digitalScaleRate,
    required this.digitalScaleTimeout,
    required this.digitalScaleBt,
    required this.continuosRead,
  }) {

    bool resp = true;

    if (!digitalScaleBt) {
      serialPort = SerialPort(digitalScalePort);

      resp = open();
    }

    if (resp) {
      try {
        config();

        if (!continuosRead) {
          writeInPort(initString);
        }

        readPort();
      } catch (_) {}
    }
  }

  /// Open the port for Read and Write
  @override
  bool open() {
    if (serialPort.isOpen) {
      try {
        closeSerialPort();
      } catch (e) {
        try {
          saveLogToFile('open port $e');
        } catch (_) {}
      }
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
        factor = continuosRead? 1 : 1000;
        stopBits = 1;
        bits = 8;
        parity = 0;
        break;
      case 'urano':
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
        factor = 1000;
        stopBits = 1;
        bits = 8;
        parity = 0;
    }

    if (!digitalScaleBt) {
      SerialPortConfig config = serialPort.config;
      config.baudRate = digitalScaleRate;
      config.stopBits = stopBits;
      config.bits = bits;
      config.parity = parity;
      serialPort.config = config;
    }
  }

  /// write enq in port
  @override
  Future<void> writeInPort(String value) async{
    try {
      if (!digitalScaleBt){
        serialPort.write(utf8.encoder.convert(value));
      }
    } catch (e) {
      try {
        saveLogToFile('write port $e');
      } catch (_) {}
    }
  }

  /// read the port
  @override
  readPort() {
    try {

      if (!digitalScaleBt){
        serialPortReader = SerialPortReader(serialPort);
      }

    } catch (e) {
      try {
        saveLogToFile('read port $e');
      } catch (_) {}
    }
  }

  /// create the listener and return the weight
  @override
  Future<double> getWeight() async {

    final roundAbnt = RoundAbnt();
    Map<String, ValueNotifier<double>> mapData = {};
    var completer = Completer<double>();
    String decodedWeight = '';
    StreamSubscription? subscription;

    try {
      double weight = 0.00;

      if (digitalScaleBt){

        connectionBt = await BluetoothConnection.toAddress(digitalScalePort);

        try {
          connectionBt.output.add(utf8.encoder.convert(initString));
          await connectionBt.output.allSent;
        } catch (_) {}

        connectionBt.input?.listen((Uint8List data) {
          decodedWeight = utf8.decode(data);
          connectionBt.output.add(data);
          connectionBt.finish();

        }).onDone(() {
          if (continuosRead){

            try {
              decodedWeight = decodedWeight
                  .replaceAll(RegExp(r'[^\d.]'), '').substring(0,6);
            } catch(_){}

          } else {
            int idxN0 = decodedWeight.indexOf('N0');
            int idxKg = decodedWeight.indexOf('kg');

            if (idxN0 > -1 && idxKg > -1) {
              decodedWeight = decodedWeight
                  .substring(idxN0 + 2, idxKg)
                  .replaceAll(',', '.')
                  .trim();
            }

          }

          if (decodedWeight.length > 1) {
            weight = ((double.parse(decodedWeight.trim())) / factor);
            weight = roundAbnt.roundAbnt(weight, 3);
          }

          completer.complete(weight);

        });

        await Future.any([
          completer.future,
          Future.delayed(Duration(milliseconds: digitalScaleTimeout))
        ]);

        return 1.0 * weight;

      } else {

        subscription = serialPortReader.stream.listen((data) async {
          decodedWeight += utf8.decode(data);

          if (decodedWeight.isEmpty){
            weight = 0.0;
            mapData['weight'] = ValueNotifier<double>(weight);

            completer.complete(mapData['weight']?.value);
            subscription?.cancel();

          } else {

            if (continuosRead){

              try {
                decodedWeight = decodedWeight
                    .replaceAll(RegExp(r'[^\d.]'), '').substring(0,6);
              } catch(_){}

            } else {
              if (digitalScaleModel.toLowerCase().contains('urano')) {
                int idxN0 = decodedWeight.indexOf('N0');
                int idxKg = decodedWeight.indexOf('kg');

                if (idxN0 > -1 && idxKg > -1) {
                  decodedWeight = decodedWeight
                      .substring(idxN0 + 2, idxKg)
                      .replaceAll(',', '.')
                      .trim();
                }
              } else {
                try {
                  decodedWeight = decodedWeight
                      .replaceAll(RegExp(r'[^\d.]'), '');
                } catch(_){}
              }
            }

            if (decodedWeight.length > 1) {
              weight = ((double.parse(decodedWeight.trim())) / factor);
              weight = roundAbnt.roundAbnt(weight, 3);

              mapData['weight'] = ValueNotifier<double>(weight);

              completer.complete(mapData['weight']?.value);
              subscription?.cancel();
            }
          }
        });

        await Future.any([
          completer.future,
          Future.delayed(Duration(milliseconds: digitalScaleTimeout))
        ]);

        closeSerialPort();

        return 1.0 * weight;
      }

    } catch (e) {
      if (kDebugMode) print('digital scale error: $e');

      try {
        await saveLogToFile('digital scale error: $e');
      } catch (_) {}

      if (!digitalScaleBt) {
        closeSerialPort();
        subscription?.cancel();
      }
      return -99.99;
    }
  }

  /// close serial port
  @override
  closeSerialPort() {
    try{
      serialPort.close();
    } catch(_){}
  }

  /// save log error in a file
  @override
  saveLogToFile(String log) {
    final directory = Directory.current;
    final file = File('${directory.path}/digital_scale_error.log');

    file.writeAsStringSync('$log \n', mode: FileMode.append);
  }
}
