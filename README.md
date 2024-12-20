[![Project Owner](https://img.shields.io/badge/owner-sergiotucano-dd8800)](https://github.com/sergiotucano/)
[![GitHub stars](https://img.shields.io/github/stars/sergiotucano/digital_scale?style=social)](https://github.com/sergiotucano/roundabnt)
[![GitHub forks](https://img.shields.io/github/forks/sergiotucano/digital_scale?style=social)](https://github.com/sergiotucano/roundabnt/fork)

# Digital Scale

This package read a weight from digital scale by serial, usb or bluetooth port

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

  /// digital scale models to send in digitalScaleModel param:
  /// Toledo Prix 3
  /// Elgin DP1502
  /// Urano

  /// call Digital Scale and pass arguments
  final digitalScale = DigitalScale(
      digitalScalePort: 'COM1',
      digitalScaleModel: 'toledo prix 3',
      digitalScaleRate: 9600,
      digitalScaleTimeout: 3000,
      digitalScaleBt: false,
      continuosRead: false,
  );

  /// async return of weight
  digitalScale.getWeight().then((resp) => print('weight $resp'));
}
```

## Digital Scale Params
    ### digitalScalePort : Com port for communication
    ### digitalScaleModel : Model of Digital Scale (See below)
    ### digitalScaleRate : bit rat of communication
    ### digitalScaleTimeout : Timeout of communication
    ### digitalScaleBt : If digital scale is a bluetooth device
    ### continuosRead : if use continuous read protocol


## Digital Scales tested

 - ### Toledo Prix 3
   - #### Configuration
     - Protocol Ptr1
     - recommended timeout 3000 ms
     
 - ### Elgin DP-1502
   - #### Configuration
     - Data1 300030
     - Prog RS232 1030
     - recommended timeout 5000 ms
     
 - ### URANO
   - ### URANO POP LIGHT
     - #### Configuration
         - stopbits 2
         - recommended timeout 3000 ms
   - ### URANO US20/2 POP-S
     - #### Configuration
       - Protocol USE-P2
       - recommended timeout 3000 ms     
   - ### URANO US31/2 POP-S
     - #### Configuration
       - Protocol USE-P2
       - recommended timeout 3000 ms
      
## Log Error
 - Any error in weight reader, open or write port a log error will be create. 
 - digital_scale_error.log in app directory