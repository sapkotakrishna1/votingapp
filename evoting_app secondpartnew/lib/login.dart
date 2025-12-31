import 'package:evoting_app/config.dart';
//import 'package:evoting_app/disclaimer_popup.dart';
import 'package:flutter/material.dart';
import 'home.dart';
import 'adminhome.dart';
import 'register.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

class LoginPage extends StatefulWidget {
  final String? showMessage;
  const LoginPage({super.key, this.showMessage});

  @override
  _LoginPageState createState() => _LoginPageState();
}

// Formatter for XX-XX-XX-XXXXX
class CitizenNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    String formatted = '';
    for (int i = 0; i < digits.length; i++) {
      formatted += digits[i];
      if (i == 1 || i == 3 || i == 5) formatted += '-';
    }
    if (formatted.length > 14) formatted = formatted.substring(0, 14);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  final TextEditingController citizenNumber = TextEditingController();
  final TextEditingController password = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Existing snackbar
      if (widget.showMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.showMessage!),
            backgroundColor: Colors.green,
          ),
        );
      }

      // // ⏱ Show disclaimer popup
      // showModalBottomSheet(
      //   context: context,
      //   isDismissible: false,
      //   enableDrag: false,
      //   backgroundColor: Colors.transparent,
      //   isScrollControlled: true,
      //   builder: (_) => const DisclaimerPopup(),
      // );
    });
  }

  Future loginUser() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    try {
      var uri = Uri.parse(Config.login);
      var response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "citizen_number": citizenNumber.text,
          "password": password.text,
        }),
      );

      var resBody = jsonDecode(response.body);

      if (resBody['success'] != null) {
        String role = resBody['role'] ?? 'user';
        String fullname = resBody['fullname'] ?? 'User';
        String citizenNum = citizenNumber.text;

        // ------------------------------
        // ✅ PASS DISTRICT FROM API HERE
        // ------------------------------
        String district = resBody["district"] ?? "Unknown";

        if (role == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AdminHomeScreen(
                username: fullname,
                citizenNumber: citizenNum,
                district: district,
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => HomeScreen(
                username: fullname,
                citizenNumber: citizenNum,
                loggedDistrict: district, // <-- FINAL FIX
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(resBody['error'] ?? "Login failed")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  InputDecoration buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withOpacity(0.1),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.white, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.white38, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(25),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.white24, width: 1.5),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Login",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 25),
                    TextFormField(
                      controller: citizenNumber,
                      decoration: buildInputDecoration(
                          "Citizen Number (XX-XX-XX-XXXXX)"),
                      keyboardType: TextInputType.number,
                      inputFormatters: [CitizenNumberFormatter()],
                      style: const TextStyle(color: Colors.white),
                      validator: (v) {
                        if (v == null || v.isEmpty) return "Required";
                        final pattern = RegExp(r'^\d{2}-\d{2}-\d{2}-\d{5}$');
                        if (!pattern.hasMatch(v))
                          return "Enter valid format: XX-XX-XX-XXXXX";
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: password,
                      decoration: buildInputDecoration("Password"),
                      obscureText: true,
                      validator: (v) => v!.isEmpty ? "Required" : null,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : loginUser,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                          backgroundColor: Colors.white,
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(
                                color: Color(0xFF8E2DE2),
                              )
                            : const Text(
                                "Login",
                                style: TextStyle(
                                  color: Color(0xFF8E2DE2),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const RegistrationPage()),
                        );
                      },
                      child: const Text(
                        "New user? Register here",
                        style: TextStyle(
                          color: Colors.white70,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
