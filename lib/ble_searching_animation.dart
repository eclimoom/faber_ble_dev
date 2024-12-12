import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class BluetoothSearchingAnimation extends StatefulWidget {
  const BluetoothSearchingAnimation({super.key});

  @override
  BluetoothSearchingAnimationState createState() => BluetoothSearchingAnimationState();
}

class BluetoothSearchingAnimationState extends State<BluetoothSearchingAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _angleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _angleAnimation = Tween<double>(begin: -30, end: 30).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller..repeat(reverse: true),
            builder: (context, child) {
              return Transform.rotate(
                angle: _angleAnimation.value * 0.0174533, // Convert degrees to radians
                child: Icon(
                  Icons.bluetooth_searching,
                  size: 20.w,
                  color: Colors.black,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}