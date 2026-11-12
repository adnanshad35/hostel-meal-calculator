import 'dart:ffi';

/// True on a phone running 32-bit Android, which needs the 32-bit APK.
bool get isArm32 => Abi.current() == Abi.androidArm;
