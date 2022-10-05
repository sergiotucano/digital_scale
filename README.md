# Digital Scale

This package read a weight from digital scale by serial port 

[![Project Owner](https://img.shields.io/badge/owner-sergiotucano-dd8800)](https://github.com/sergiotucano/)
[GitHub stars](https://img.shields.io/github/stars/sergiotucano/digital_scale?style=social)
[![GitHub forks](https://img.shields.io/github/forks/sergiotucano/digital_scale?style=social)](https://github.com/sergiotucano/roundabnt/fork)

## Installation

```bash
flutter pub add digital_scale
```

## Import

```dart
import 'package:digital_scale/digital_scale.dart';
```

## Example

```dart
void main() {

  /// call Digital Scale and pass arguments
  final digitalScale = DigitalScale('COM1', 'toledo prix 3');

  /// async return of weight
  digitalScale.getWeight().then((resp) => print('weight $resp'));
}
```

## Digital Scales tested

 - ### Toledo Prix 3
   - #### Configuration
     - BaundRate 115200 
     - Protocol Ptr1
   
 - ### Elgin DP-1502
   - #### Configuration
     - Data1 300030
     - Prog RS232 1130

 - ### URANO POP LIGHT
   - #### Configuration
       - BaundRate 9600
       - stopbits 2