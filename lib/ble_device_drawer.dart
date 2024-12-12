import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err),
      ));
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
        if (kDebugMode) {
          print("Error $err");
        }
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Scanning for bluetooth devices ...'),
        ));
      }
    } else {
      final messages = {
        BluetoothState.unsupported:
        'Bluetooth is not supported on this device.',
        BluetoothState.poweredOff: 'Please switch on bluetooth and try again.',
        BluetoothState.poweredOn: 'Everything is fine.',
        BluetoothState.resetting: 'Currently resetting. Try again later.',
        BluetoothState.unauthorized:
        'This app needs bluetooth permissions. Please open settings, find your app and assign bluetooth access rights and start your app again.',
        BluetoothState.unknown: 'Bluetooth is not ready yet. Try again later.',
        BluetoothState.other:
        'This should never happen. Please inform the developer of your app.',
      };
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red,
          content: Text(messages[_midiCommand.bluetoothState] ??
              'Unknown bluetooth state: ${_midiCommand.bluetoothState}'),
        ));
      }
    }

    if (kDebugMode) {
      print("done");
    }
    // If not show a message telling users what to do
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 120.w,
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 29.sp, // Set the drawer header height
            child: DrawerHeader(
              padding: EdgeInsets.fromLTRB(6.sp, 0, 0, 0),
              margin: const EdgeInsets.all(0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Text(
                '列表',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8.sp,
                ),
              ),
            ),
          ),
          Expanded(
            child: DeviceTile(midiCommand: _midiCommand),
          ),
          // Add more ListTile widgets for additional devices
        ],
      ),
    );
  }
}
class DeviceTile extends StatelessWidget {
  final MidiCommand midiCommand;

  const DeviceTile({super.key, required this.midiCommand});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: midiCommand.devices,
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            var devices = snapshot.data as List<MidiDevice>;
            // var devices = [
            //   MidiDevice('1', 'aaaaaaa', 'this.type', false),
            //   MidiDevice('2', 'aa', 'this.type', true),
            // ];
            devices.add(MidiDevice('2', 'PIANO MIDI', 'BLE', false));
            devices.add(MidiDevice('2', 'PIANO MIDI', 'native', false));


            debugPrint("devices: ${devices.length}");
            if (devices.isEmpty) {
              return const Center(
                child: Text("未找到设备", style: TextStyle(fontSize: 20, color: Colors.grey)),
              );
            }
            return SizedBox(
              height: 200, // Set an appropriate height for the ListView
              child: ListView.builder(
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  MidiDevice device = devices[index];
                  return ListTile(
                    title: Text(
                      device.name,
                      style: Theme.of(context).textTheme.headlineSmall,
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
      return Icons.devices;
    case "BLE":
      return Icons.bluetooth;
    default:
      return Icons.device_unknown;
  }
}
