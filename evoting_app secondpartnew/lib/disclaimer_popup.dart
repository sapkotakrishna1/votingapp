import 'dart:async';
import 'package:flutter/material.dart';

class DisclaimerPopup extends StatefulWidget {
  const DisclaimerPopup({super.key});

  @override
  State<DisclaimerPopup> createState() => _DisclaimerPopupState();
}

class _DisclaimerPopupState extends State<DisclaimerPopup> {
  int countdown = 10;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (countdown == 0) {
        Navigator.pop(context);
        t.cancel();
      } else {
        setState(() => countdown--);
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Responsive width and height
    final double width = MediaQuery.of(context).size.width * 0.85;
    final double height = MediaQuery.of(context).size.height * 0.55;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: width,
          height: height,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2C),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Countdown top-left
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.deepPurpleAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "$countdown",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Skip top-right
              Positioned(
                top: 0,
                right: 0,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Skip",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),

              // Content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.how_to_vote,
                        color: Colors.deepPurpleAccent, size: 80),
                    SizedBox(height: 16),
                    Text(
                      "E-Voting System",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Only verified citizens are allowed to login and vote.\n\n"
                      "Any misuse of this system is punishable by law.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
