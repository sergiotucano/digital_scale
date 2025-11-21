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
  static int factor = 1;
  static String initString = '';
  final bool digitalScaleBt;
  final bool continuosRead;
  static late BluetoothConnection connectionBt;
  final bool saveLogFile;

  /// initialize the serial port and call methods
  DigitalScale({
    required this.digitalScalePort,
    required this.digitalScaleModel,
    required this.digitalScaleRate,
    required this.digitalScaleTimeout,
    required this.digitalScaleBt,
    required this.continuosRead,
    required this.saveLogFile,
  }) {
    bool resp = true;

    if (!digitalScaleBt) {
      serialPort = SerialPort(digitalScalePort);
      resp = open();
    }

    if (resp) {
      try {
        config();
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
          saveLogToFile('open port $e', 'error');
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
        factor = continuosRead ? 1 : 1000;
        stopBits = 1;
        bits = 8;
        parity = 0;
        break;

      case 'upx':
        initString = String.fromCharCode(5);
        factor = 1;
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
      config.dtr = 0;
      config.rts = 0;
      serialPort.config = config;
    }
  }

  /// write enq in port
  @override
  Future<void> writeInPort(String value) async {
    try {
      if (!digitalScaleBt) {
        serialPort.flush();
        serialPort.write(utf8.encoder.convert(value));
      }
    } catch (e) {
      try {
        saveLogToFile('write port $e', 'error');
      } catch (_) {}
    }
  }

  /// DIRECT READ — NO STREAM — POLLING
  Future<String> _readDirectSerial() async {
    final StringBuffer buffer = StringBuffer();

    const int inactivityTimeoutMs = 300;
    const int pollIntervalMs = 10;
    const int maxBytes = 4096;

    final int startTotal = DateTime.now().millisecondsSinceEpoch;
    int lastActivity = startTotal;

    while (true) {

      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - startTotal > digitalScaleTimeout) {
        break;
      }

      final bytes = serialPort.read(512);

      if (bytes != null && bytes.isNotEmpty) {
        buffer.write(utf8.decode(bytes, allowMalformed: true));
        lastActivity = now;

        if (buffer.length > maxBytes) break;
      } else {
        if (now - lastActivity > inactivityTimeoutMs) {
          break;
        }
        await Future.delayed(const Duration(milliseconds: pollIntervalMs));
      }

      final text = buffer.toString();
      if (text.contains('\n') || text.contains('\r')) break;
    }

    return buffer.toString();
  }

  /// create the reader and return the weight
  @override
  Future<double> getWeight() async {
    final roundAbnt = RoundAbnt();
    double weight = 0.0;

    try {
      //-----------------------------
      // BLUETOOTH
      //-----------------------------
      if (digitalScaleBt) {
        connectionBt = await BluetoothConnection.toAddress(digitalScalePort);

        connectionBt.output.add(utf8.encoder.convert(initString));
        await connectionBt.output.allSent;

        Uint8List raw = Uint8List(0);

        await connectionBt.input?.first.then((value) {
          raw = value;
        });

        String decoded = utf8.decode(raw);

        if (continuosRead) {
          try {
            decoded = decoded.replaceAll(RegExp(r'[^\d.]'), '').
            substring(0, 6);
          } catch (_) {}
        } else {
          int idxN0 = decoded.indexOf('N0');
          int idxKg = decoded.indexOf('kg');

          if (idxN0 > -1 && idxKg > -1) {
            decoded = decoded
                .substring(idxN0 + 2, idxKg)
                .replaceAll(',', '.')
                .trim();
          }
        }

        if (decoded.length > 1) {
          weight = double.parse(decoded) / factor;
          weight = roundAbnt.roundAbnt(weight, 3);
        }

        return weight;
      }

      // deadline timeout total
      final deadline = DateTime.now()
          .add(Duration(milliseconds: digitalScaleTimeout));

      //-----------------------------
      // SERIAL — DIRECT READ
      //-----------------------------

      saveLogToFile('0 - inicio leitura direta ${DateTime.now()}', 'normal');
      while (DateTime.now().isBefore(deadline)) {
        await writeInPort(initString);

        final rawResponse = await _readDirectSerial();

        saveLogToFile(
          '1 - resposta lida  ${DateTime.now()} → $rawResponse', 'normal'
        );

        String decoded = rawResponse;

        // CONTINUOS
        if (continuosRead) {
          try {
            decoded =
                decoded.replaceAll(RegExp(r'[^\d.]'), '').substring(0, 6);
          } catch (_) {}
        }

        // URANO / TOLEDO / OTHERS
        else {
          if (digitalScaleModel.toLowerCase().contains('urano')) {
            int idxN0 = decoded.indexOf('N0');
            int idxKg = decoded.indexOf('kg');

            if (idxN0 > -1 && idxKg > -1) {
              decoded = decoded
                  .substring(idxN0 + 2, idxKg)
                  .replaceAll(',', '.')
                  .trim();
            }
          } else {
            decoded = decoded.replaceAll(RegExp(r'[^\d.]'), '');
          }
        }

        if (decoded.isEmpty) {
          await Future.delayed(const Duration(milliseconds: 20));
          continue;
        }

        try {
          weight = double.parse(decoded) / factor;
          weight = roundAbnt.roundAbnt(weight, 3);
        } catch (_) {
          weight = 0.0;
        }

        if (weight == 0.0) {
          await Future.delayed(const Duration(milliseconds: 20));
          continue;
        }

        break;
      }
      closeSerialPort();

      saveLogToFile('2 - weight → $weight', 'normal');

      return weight;
    } catch (e) {
      if (kDebugMode) print('digital scale error: $e');

      try {
        await saveLogToFile('digital scale error: $e','error');
      } catch (_) {}

      closeSerialPort();
      return -99.99;
    }
  }

  @override
  closeSerialPort() {
    try {
      serialPort.close();
    } catch (_) {}
  }

  @override
  saveLogToFile(String log, String mode) {
    bool canSavelog = true;

    if (mode == 'normal' && !saveLogFile){
      canSavelog = false;
    }

    if (canSavelog) {
      final fileName = mode == 'error'
          ? 'digital_scale_error.log'
          : 'digital_scale.log';
      final directory = Directory.current;
      final file = File('${directory.path}/Logs/$fileName');
      file.writeAsStringSync('$log \n', mode: FileMode.append);
    }

    if (kDebugMode) print(log);

  }
}
