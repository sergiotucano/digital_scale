
import 'package:digital_scale/digital_scale.dart';

/// example how to use the digital scale package
void main() {

  /// call Digital Scale and pass arguments
  final digitalScale = DigitalScale('COM1', 'toledo prix 3');

  /// async return of weight
  digitalScale.getWeight().then((resp) => print('weight $resp'));
}