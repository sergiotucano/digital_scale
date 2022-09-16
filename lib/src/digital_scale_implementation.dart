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
  /// read the port
  readPort();
  /// create the listener, get the weight and return in double format.
  Future<double>getWeight();
}