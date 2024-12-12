import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';

import 'ble_searching_animation.dart';

class BleDeviceDrawer extends StatefulWidget {
  const BleDeviceDrawer({
    super.key,
  });

  @override
  State<BleDeviceDrawer> createState() => _BleDeviceDrawerState();
}

class _BleDeviceDrawerState extends State<BleDeviceDrawer> {
  final MidiCommand _midiCommand = MidiCommand();
  bool _didAskForBluetoothPermissions = false;

  String _message = '正在搜索蓝牙设备 ...';
  final messages = {
    BluetoothState.unsupported: '此设备不支持蓝牙。',
    BluetoothState.poweredOff: '请打开蓝牙后重试。',
    BluetoothState.poweredOn: '一切正常。',
    BluetoothState.resetting: '当前正在重置。请稍后再试。',
    BluetoothState.unauthorized: '此应用需要蓝牙权限。请打开设置，找到您的应用并分配蓝牙访问权限，然后重新启动您的应用。',
    BluetoothState.unknown: '蓝牙尚未准备好。请稍后再试。',
    BluetoothState.other: '这不应该发生。请通知您的应用开发者。',
  };

  @override
  void initState() {
    super.initState();
    _requestBluetoothPermissions();
  }

  void _requestBluetoothPermissions() async {
    if (!_didAskForBluetoothPermissions) {
      _didAskForBluetoothPermissions = true;
      await Permission.bluetooth.request();
      await Permission.bluetoothScan.request();
      await Permission.bluetoothConnect.request();
      _scanForDevices();
    }
  }

  void _scanForDevices() async {
    debugPrint("start ble central");
    await _midiCommand.startBluetoothCentral().catchError((err) {
      setState(() {
        _message = err.toString();
      });
    });

    debugPrint("ble scan init");
    await _midiCommand
        .waitUntilBluetoothIsInitialized()
        .timeout(const Duration(seconds: 5), onTimeout: () {
      debugPrint("Failed to initialize Bluetooth");
    });

    // If bluetooth is powered on, start scanning
    if (_midiCommand.bluetoothState == BluetoothState.poweredOn) {
      _midiCommand.startScanningForBluetoothDevices().catchError((err) {
        setState(() {
          _message = "Error: $err";
        });
      });
    } else {
      setState(() {
        _message = messages[_midiCommand.bluetoothState] ??
            'Unknown bluetooth state: ${_midiCommand.bluetoothState}';
      });
    }

    if (kDebugMode) {
      print("done");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 120.w,
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 29.sp,
            width: double.infinity,
            child: DrawerHeader(
              padding: EdgeInsets.fromLTRB(6.sp, 0, 0, 0),
              margin: const EdgeInsets.all(0),
              child: Text(
                '设备列表',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 8.sp,
                ),
              ),
            ),
          ),
          Expanded(
            child: DeviceTile(
              midiCommand: _midiCommand,
              message: _message,
            ),
          ),
          // Add more ListTile widgets for additional devices
        ],
      ),
    );
  }
}

class DeviceTile extends StatelessWidget {
  final MidiCommand midiCommand;
  final String message;

  const DeviceTile(
      {super.key, required this.midiCommand, required this.message});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: midiCommand.devices,
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            var devices = snapshot.data as List<MidiDevice>;
            // devices.add(MidiDevice('2', 'ECG 1', 'BLE', false));
            // devices.add(MidiDevice('2', 'ECG 2', 'native', false));

            debugPrint("devices: ${devices.length}");
            if (devices.isEmpty) {
              return Column(
                children: [
                  const SizedBox(height: 40),
                  const BluetoothSearchingAnimation(),
                  Container(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(message, style: const TextStyle(fontSize: 20, color: Colors.black)),
                  ),
                ],
              );
            }
            return Column(
              children: [

                SizedBox(
                  height: 200, // Set an appropriate height for the ListView
                  child: ListView.builder(
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      MidiDevice device = devices[index];
                      return ListTile(
                        title: Text(
                          device.name,
                          style: TextStyle(
                            color:
                                device.connected ? Colors.green : Colors.black,
                            fontSize: 6.sp,
                          ),
                        ),
                        subtitle: Text(
                            "输入端口:${device.inputPorts.length}个 输出端口:${device.outputPorts.length}个, ${device.id}, ${device.type}"),
                        leading: Icon(device.connected
                            ? Icons.radio_button_on
                            : Icons.radio_button_off),
                        trailing: Icon(_deviceIconForType(device.type)),
                        onLongPress: () {
                          midiCommand.stopScanningForBluetoothDevices();

                          Navigator.pop(context);
                          debugPrint("device selected, ${device.toString()}");
                        },
                        onTap: () {
                          if (device.connected) {
                            if (kDebugMode) {
                              print("disconnect");
                            }
                            midiCommand.disconnectDevice(device);
                          } else {
                            if (kDebugMode) {
                              print("connect");
                            }
                            midiCommand.connectToDevice(device).then((_) {
                              if (kDebugMode) {
                                print("device connected async");
                              }
                            }).catchError((err) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(
                                      "Error: ${(err as PlatformException?)?.message}")));
                            });
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          } else {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        });
  }
}

IconData _deviceIconForType(String type) {
  switch (type) {
    case "native":
      return Icons.route;
    case "BLE":
      return Icons.bluetooth;
    default:
      return Icons.device_unknown;
  }
}
