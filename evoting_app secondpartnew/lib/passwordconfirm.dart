import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart' hide Config;
import 'config.dart';

class PasswordConfirmationPage extends StatefulWidget {
  final String loggedCitizenID;

  const PasswordConfirmationPage({super.key, required this.loggedCitizenID});

  /// Utility function to show the page and get confirmation result
  static Future<bool> show(BuildContext context, String loggedCitizenID) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PasswordConfirmationPage(loggedCitizenID: loggedCitizenID),
      ),
    );
    return result ?? false;
  }

  @override
  State<PasswordConfirmationPage> createState() =>
      _PasswordConfirmationPageState();
}

class _PasswordConfirmationPageState extends State<PasswordConfirmationPage> {
  final TextEditingController passwordController = TextEditingController();
  bool obscurePassword = true;
  bool isLoading = false;

  // ---------------- Face variables ----------------
  CameraController? cameraController;
  bool cameraReady = false;

  @override
  void dispose() {
    cameraController?.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ---------------- Camera Initialization ----------------
  Future<void> initCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras
          .firstWhere((cam) => cam.lensDirection == CameraLensDirection.front);

      cameraController = CameraController(frontCamera, ResolutionPreset.medium,
          enableAudio: false);

      await cameraController!.initialize();
      if (!mounted) return;

      setState(() {
        cameraReady = true;
      });
    } catch (e) {
      print("Camera error: $e");
    }
  }

  // ---------------- Password Verification ----------------
  Future<bool> verifyPassword(String password) async {
    final uri = Uri.parse(Config.verifypassword);
    try {
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "citizenID": widget.loggedCitizenID.trim(),
          "password": password.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["success"] == true;
      }
    } catch (e) {
      print("Password verification error: $e");
    }
    return false;
  }

  // ---------------- Face Verification ----------------
  Future<bool> verifyFace() async {
    if (cameraController == null || !cameraController!.value.isInitialized) {
      return false;
    }

    final image = await cameraController!.takePicture();
    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);

    try {
      final response = await http.post(
        Uri.parse(Config.verifyFaceUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "citizenID": widget.loggedCitizenID,
          "image": base64Image,
        }),
      );

      // 🔴 ADD THESE DEBUG PRINTS
      print("STATUS CODE: ${response.statusCode}");
      print("RAW RESPONSE:");
      print(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["success"] == true;
      }
    } catch (e) {
      print("Face verification error: $e");
    }

    return false;
  }

  // ---------------- Confirm with Password ----------------
  Future<void> confirmPassword() async {
    setState(() => isLoading = true);

    bool isValid = await verifyPassword(passwordController.text);

    setState(() => isLoading = false);

    if (isValid) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Wrong password!"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ---------------- Confirm with Face ----------------
  Future<void> confirmFace() async {
    setState(() => isLoading = true);

    // Initialize camera only when user clicks face confirm
    if (cameraController == null) {
      await initCamera();
    }

    if (!cameraReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Camera not ready!"),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => isLoading = false);
      return;
    }

    bool isValid = await verifyFace();

    setState(() => isLoading = false);

    if (isValid) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Face verification failed!"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Confirm Identity"),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Verify your identity",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 25),

            // Password field
            TextField(
              controller: passwordController,
              obscureText: obscurePassword,
              decoration: InputDecoration(
                labelText: "Password",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                prefixIcon: const Icon(Icons.lock, color: Colors.deepPurple),
                suffixIcon: IconButton(
                  icon: Icon(obscurePassword
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () {
                    setState(() {
                      obscurePassword = !obscurePassword;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 25),

            // Camera preview for face verification
            if (cameraReady)
              SizedBox(
                height: 200,
                child: CameraPreview(cameraController!),
              ),

            const SizedBox(height: 25),

            // ---------------- Buttons ----------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: isLoading ? null : confirmPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 20),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text("Confirm with Password"),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : confirmFace,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 20),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text("Confirm with Face"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
