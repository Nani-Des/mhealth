import 'package:flutter/material.dart';
import 'dart:async';

class SpeechBubble extends StatefulWidget {
  final VoidCallback onPressed;
  final TextStyle textStyle;

  SpeechBubble({required this.onPressed, required this.textStyle});

  @override
  _SpeechBubbleState createState() => _SpeechBubbleState();
}

class _SpeechBubbleState extends State<SpeechBubble> {
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _startBlinking();
  }

  void _startBlinking() {
    Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _isVisible = !_isVisible;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed,
      child: Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite, color: Colors.red),
            SizedBox(width: 10),
            AnimatedOpacity(
              opacity: _isVisible ? 1.0 : 0.0,
              duration: Duration(milliseconds: 500),
              child: Text(
                'Featured Doctors near you!',
                style: widget.textStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
