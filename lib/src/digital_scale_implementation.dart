import 'package:flutter/foundation.dart';

/// This method read from digital Scale a weight
@immutable
abstract class DigitalScaleImplementation {
  /// open Serial Port
  bool open();

  /// configure Serial Port
  config();

  /// write in serial port the enq byte
  writeInPort(String value);

  /// create the listener, get the weight and return in double format.
  Future<double> getWeight();

  /// Error log
  saveLogToFile(String log, String mode);

  /// close serial port
  closeSerialPort();

  ///read byte data
  Future<String> readDirectSerial();

  /// start continuous mode
  void startContinuousRead();

  ///stop continuous mode
  void stopContinuousRead();

  /// parse for continuous mode
  double? parseWeight(String raw);

}
