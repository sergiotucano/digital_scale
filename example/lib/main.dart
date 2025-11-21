
import 'package:digital_scale/digital_scale.dart';

/// example how to use the digital scale package
void main() {

  /// call Digital Scale and pass arguments
  final digitalScale = DigitalScale(
      digitalScalePort: 'COM1',
      digitalScaleModel: 'toledo prix 3',
      digitalScaleRate: 9600,
      digitalScaleTimeout: 3000,
      digitalScaleBt: false,
      continuosRead: false,
      saveLogFile: true,
  );

  /// async return of weight
  digitalScale.getWeight().then((resp) => print('weight $resp'));
}