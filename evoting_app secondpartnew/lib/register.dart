// registration_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui_web' as ui;
import 'package:camera/camera.dart';
import 'package:evoting_app/disclaimer_popup.dart';
import 'config.dart';
//import 'dart:js_util' as js_util;
import 'dart:typed_data';
import 'dart:html' as html;
// ignore: unused_import
import 'ui_stub.dart' if (dart.library.html) 'ui_web.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'login.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// ===== Formatters =====
class CitizenNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.length < oldValue.text.length) return newValue;
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    String formatted = '';
    for (int i = 0; i < digitsOnly.length && i < 12; i++) {
      formatted += digitsOnly[i];
      if (i == 1 || i == 3 || i == 5) {
        if (digitsOnly.length != i + 1) formatted += '-';
      }
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class DateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.length < oldValue.text.length) return newValue;
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    String formatted = '';
    for (int i = 0; i < digitsOnly.length && i < 8; i++) {
      formatted += digitsOnly[i];
      if (i == 3 || i == 5) {
        if (digitsOnly.length != i + 1) formatted += '-';
      }
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length > 10) digitsOnly = digitsOnly.substring(0, 10);

    String formatted = '';
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i == 3 || i == 6) formatted += ' ';
      formatted += digitsOnly[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// ===== Registration Page =====
class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});
  @override
  _RegistrationPageState createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final formKey = GlobalKey<FormState>();

  final TextEditingController fullName = TextEditingController();
  final TextEditingController dob = TextEditingController();
  final TextEditingController district = TextEditingController();
  final TextEditingController citizenNumber = TextEditingController();
  final TextEditingController phone = TextEditingController();
  final TextEditingController password = TextEditingController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.6),
        builder: (_) => const DisclaimerPopup(),
      );
    });
  }

  XFile? frontImage;
  XFile? backImage;
  XFile? selfieImage;
  bool useBackCamera = false; // inside the function
  Uint8List? selfieWebImage; // Web
  bool isLoading = false;
  bool verificationPassed = false;
  bool passwordVisible = false;
  int currentStep = 0;
  bool isFaceDetected = false; // <-- new field

  final ImagePicker _picker = ImagePicker();

  /// ===== Pick Images =====
  Future<void> pickImage(bool isFront, ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() {
        if (isFront)
          frontImage = picked;
        else
          backImage = picked;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Image pick error: ${e.toString()}")));
    }
  }

  Future<bool> requestCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    return status.isGranted;
  }

  Future<void> takeSelfie() async {
    if (kIsWeb) {
      // ===== Web =====
      html.VideoElement videoElement = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..width = 320
        ..height = 240
        ..setAttribute('playsinline', 'true');

      html.CanvasElement overlay = html.CanvasElement(
        width: videoElement.width,
        height: videoElement.height,
      );

      html.DivElement container = html.DivElement()
        ..style.position = 'relative'
        ..style.width = '${videoElement.width}px'
        ..style.height = '${videoElement.height}px';

      videoElement.style.position = 'absolute';
      overlay.style.position = 'absolute';
      container.children.addAll([videoElement, overlay]);

      // ignore: undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory(
        'web-camera-video',
        (int viewId) => container,
      );

      bool cameraBack = useBackCamera;
      Uint8List? capturedImage;
      Timer? faceTimer;
      html.MediaStream? stream;

      void stopCamera() {
        try {
          stream?.getTracks().forEach((track) => track.stop());
          stream = null;
          videoElement.srcObject = null; // ✅ Important!
        } catch (_) {}
      }

      // Start camera
      Future<html.MediaStream> startCamera(bool backCamera) async {
        final s = await html.window.navigator.mediaDevices!.getUserMedia({
          'video': {'facingMode': backCamera ? 'environment' : 'user'}
        });
        videoElement.srcObject = s;
        return s;
      }

      stream = await startCamera(cameraBack);

      void detectFace() {
        final ctx = overlay.context2D;
        ctx.clearRect(0, 0, overlay.width!, overlay.height!);
        ctx.beginPath();
        ctx.arc(overlay.width! / 2, overlay.height! / 2, 50, 0, 2 * 3.14159);
        ctx.strokeStyle = capturedImage != null ? 'green' : 'red';
        ctx.lineWidth = 4;
        ctx.stroke();
        if (mounted) setState(() => isFaceDetected = capturedImage != null);
      }

      // Timer for face detection overlay
      faceTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted) {
          faceTimer?.cancel();
          faceTimer = null;
          return;
        }
        detectFace();
      });

      await showDialog(
        context: context,
        builder: (_) {
          return StatefulBuilder(
            builder: (context, setStateDialog) {
              return Dialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 320,
                              height: 240,
                              child:
                                  HtmlElementView(viewType: 'web-camera-video'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "Hold your citizenship card clearly in the selfie. "
                            "If unclear, it may be rejected by admin.",
                            style: TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange),
                                onPressed: () async {
                                  stopCamera();

                                  cameraBack = !cameraBack;
                                  stream = await startCamera(cameraBack);
                                  if (mounted) setStateDialog(() {});
                                },
                                icon: const Icon(Icons.flip_camera_android),
                                label: Text(cameraBack ? "Front" : "Back"),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green),
                                onPressed: () {
                                  final canvas = html.CanvasElement(
                                    width: videoElement.videoWidth,
                                    height: videoElement.videoHeight,
                                  );
                                  canvas.context2D
                                      .drawImage(videoElement, 0, 0);
                                  final dataUrl = canvas.toDataUrl('image/png');
                                  final base64Str = dataUrl.split(',')[1];
                                  if (mounted) {
                                    setStateDialog(() {
                                      capturedImage = base64Decode(base64Str);
                                      isFaceDetected = true;
                                    });
                                  }
                                },
                                child: const Text("Capture"),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (capturedImage != null)
                            Column(
                              children: [
                                const Text(
                                  "Preview: Retake if unclear",
                                  style: TextStyle(color: Colors.blue),
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.memory(
                                    capturedImage!,
                                    width: 200,
                                    height: 150,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  stopCamera();
                                  faceTimer?.cancel();
                                  faceTimer = null;
                                  Navigator.pop(context);
                                },
                                child: const Text("Cancel"),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: capturedImage == null
                                    ? null
                                    : () {
                                        stopCamera();
                                        faceTimer?.cancel();
                                        faceTimer = null;
                                        if (!mounted) return;
                                        setState(() =>
                                            selfieWebImage = capturedImage);
                                        Navigator.pop(context);
                                      },
                                child: const Text("OK"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } else {
      // ===== Mobile =====
      try {
        final XFile? captured = await _picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice:
              useBackCamera ? CameraDevice.rear : CameraDevice.front,
          maxWidth: 500,
          maxHeight: 500,
          imageQuality: 85,
        );

        if (captured != null) {
          final inputImage = InputImage.fromFilePath(captured.path);
          final faceDetector = FaceDetector(
            options: FaceDetectorOptions(
                enableContours: true, enableLandmarks: true),
          );

          final faces = await faceDetector.processImage(inputImage);

          if (!mounted) return;
          setState(() {
            selfieImage = captured;
            selfieWebImage = null;
            isFaceDetected = faces.isNotEmpty;
          });

          faceDetector.close();
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Camera error: $e")),
        );
      }
    }
  }

  Future<void> takeSelfieMobile() async {
    // request permission
    if (!await Permission.camera.request().isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Camera permission denied")),
      );
      return;
    }

    final cameras = await availableCameras();
    CameraDescription selectedCamera =
        useBackCamera ? cameras.first : cameras.last;

    CameraController controller = CameraController(
      selectedCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await controller.initialize();

    Uint8List? capturedBytes;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: CameraPreview(controller),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.flip_camera_android),
                        label: Text(useBackCamera ? "Front" : "Back"),
                        onPressed: () async {
                          useBackCamera = !useBackCamera;
                          await controller.dispose();
                          selectedCamera =
                              useBackCamera ? cameras.first : cameras.last;
                          controller = CameraController(
                            selectedCamera,
                            ResolutionPreset.medium,
                            enableAudio: false,
                          );
                          await controller.initialize();
                          setStateDialog(() {});
                        },
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        child: const Text("Capture"),
                        onPressed: () async {
                          final XFile file = await controller.takePicture();
                          capturedBytes = await file.readAsBytes();
                          setStateDialog(() {});
                        },
                      ),
                    ],
                  ),
                  if (capturedBytes != null)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.memory(
                        capturedBytes!,
                        height: 150,
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        child: const Text("Cancel"),
                        onPressed: () async {
                          await controller.dispose();
                          Navigator.pop(context);
                        },
                      ),
                      TextButton(
                        child: const Text("OK"),
                        onPressed: capturedBytes == null
                            ? null
                            : () async {
                                selfieWebImage = capturedBytes;
                                await controller.dispose();
                                Navigator.pop(context);
                              },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// ===== OCR Function =====
  Future<String> performOCR(XFile imageFile) async {
    if (kIsWeb) {
      Uint8List bytes = await imageFile.readAsBytes();
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(Config.ocr),
      );
      request.files.add(
          http.MultipartFile.fromBytes('image', bytes, filename: 'image.png'));
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        var res = jsonDecode(response.body);
        String text = res['text'] ?? '';
        text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
        return text;
      }
      return '';
    } else {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final recognizerNep =
          TextRecognizer(script: TextRecognitionScript.devanagiri);
      final recognizerEng = TextRecognizer(script: TextRecognitionScript.latin);

      try {
        final resultNep = await recognizerNep.processImage(inputImage);
        final resultEng = await recognizerEng.processImage(inputImage);
        String combinedText = (resultNep.text + '\n' + resultEng.text).trim();
        return combinedText;
      } finally {
        recognizerNep.close();
        recognizerEng.close();
      }
    }
  }

  /// ===== Convert Image to Base64 =====
  Future<String> convertToBase64(XFile file) async {
    Uint8List bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  /// ===== Extractors =====
  String extractCitizenNumber(String text) {
    RegExp r1 = RegExp(r'\d{2}[- ]\d{2}[- ]\d{2}[- ]\d{5}');
    RegExp r2 = RegExp(r'\d{11,12}');
    var m1 = r1.firstMatch(text.replaceAll(RegExp(r'\s'), ''));
    if (m1 != null) return m1.group(0)!;
    var m2 = r2.firstMatch(text.replaceAll(RegExp(r'\s'), ''));
    if (m2 != null) return m2.group(0)!;
    return '';
  }

  String extractDOB(String text) {
    // Match Year, Month, Day labels anywhere in the text
    RegExp labeledPattern = RegExp(
      r'(?:Year[:=]?\s*(\d{4}))|(?:Month[:=]?\s*(\d{1,2}))|(?:Day[:=]?\s*(\d{1,2}))',
      caseSensitive: false,
    );

    String? year, month, day;

    for (var match in labeledPattern.allMatches(text)) {
      if (match.group(1) != null) year = match.group(1);
      if (match.group(2) != null) month = match.group(2);
      if (match.group(3) != null) day = match.group(3);
    }

    if (year != null) {
      month = (month ?? '01').padLeft(2, '0');
      day = (day ?? '01').padLeft(2, '0');
      return '$year-$month-$day';
    }

    return '';
  }

  String extractName(String text) {
    text = text.replaceAll(RegExp(r'[\r\n]+'), ' ');
    text = text.replaceAll(RegExp(r'[^\w\s\u0900-\u097F:]'), ' ');

    // Flexible regex for name labels
    RegExp fullNameReg = RegExp(
        r'(?:Full\s*Name|FullName|Name)\s*[:=]\s*([\w\s\u0900-\u097F]{2,})',
        caseSensitive: false);
    var match = fullNameReg.firstMatch(text);
    if (match != null) {
      String name = match.group(1)!.trim();
      // Optional: split to max 5 words
      List<String> parts = name.split(RegExp(r'\s+'));
      if (parts.length > 5) parts = parts.sublist(0, 5);
      return parts.join(' ');
    }

    // Fallback: grab first multi-letter capitalized words
    RegExp fallbackReg = RegExp(
        r'([A-Z\u0900-\u097F][a-z\u0900-\u097F]{1,}(?:\s+[A-Z\u0900-\u097F][a-z\u0900-\u097F]{1,})*)');
    var fallback = fallbackReg.firstMatch(text);
    if (fallback != null) return fallback.group(1)!.trim();

    return '';
  }

  String extractDistrict(String text) {
    // English format
    RegExp engReg =
        RegExp(r'District\s*[:.\-]?\s*([A-Za-z]+)', caseSensitive: false);
    var engMatch = engReg.firstMatch(text);
    if (engMatch != null) {
      return engMatch.group(1)!.trim();
    }

    // Nepali format: जिल्ला : बागलुङ
    RegExp nepReg = RegExp(r'जिल्ला\s*[:.\-]?\s*([\u0900-\u097F]+)');
    var nepMatch = nepReg.firstMatch(text);
    if (nepMatch != null) {
      return nepMatch.group(1)!.trim();
    }

    return '';
  }

  Future<Map<String, String>> ocrAndExtractAll() async {
    String combinedText = '';
    if (frontImage != null) {
      combinedText += '\n${await performOCR(frontImage!)}';
    }
    if (backImage != null) combinedText += '\n${await performOCR(backImage!)}';

    return {
      'name': extractName(combinedText),
      'dob': extractDOB(combinedText),
      'citizen': extractCitizenNumber(combinedText),
      'district': extractDistrict(combinedText),
      'raw': combinedText,
    };
  }

  Map<String, bool> compareFields(Map<String, String> extracted) {
    bool nameMatch = extracted['name']!.isNotEmpty &&
        extracted['name']!.trim().replaceAll(RegExp(r'\s+'), '') ==
            fullName.text.trim().replaceAll(RegExp(r'\s+'), '');
    bool dobMatch =
        extracted['dob']!.isNotEmpty && extracted['dob'] == dob.text.trim();
    bool citizenMatch = extracted['citizen']!.isNotEmpty &&
        extracted['citizen']!.replaceAll(RegExp(r'[^0-9]'), '') ==
            citizenNumber.text.replaceAll(RegExp(r'[^0-9]'), '');
    bool districtMatch = extracted['district']!.isNotEmpty &&
        extracted['district']!.trim() == district.text.trim();
    return {
      'name': nameMatch,
      'dob': dobMatch,
      'citizen': citizenMatch,
      'district': districtMatch,
    };
  }

  Future<void> verifyFromImages() async {
    if (frontImage == null && backImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please add images first")));
      return;
    }
    setState(() => isLoading = true);
    try {
      final extracted = await ocrAndExtractAll();

      fullName.text = extracted['name']!;
      dob.text = extracted['dob']!;
      district.text = extracted['district']!;
      citizenNumber.text = extracted['citizen']!;

      final comparison = compareFields(extracted);
      setState(() => verificationPassed = comparison.values.every((e) => e));

      showDialog(
          context: context,
          builder: (_) => AlertDialog(
                title: Text(verificationPassed
                    ? "Verification Passed"
                    : "Verification Results"),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Extracted Name: ${extracted['name']}"),
                      Text("Name Match: ${comparison['name']! ? '✔' : '✖'}"),
                      Text("Extracted DOB: ${extracted['dob']}"),
                      Text("DOB Match: ${comparison['dob']! ? '✔' : '✖'}"),
                      Text("Extracted Citizen #: ${extracted['citizen']}"),
                      Text(
                          "Citizen Match: ${comparison['citizen']! ? '✔' : '✖'}"),
                      Text("Extracted District: ${extracted['district']}"),
                      Text(
                          "District Match: ${comparison['district']! ? '✔' : '✖'}"),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("OK"))
                ],
              ));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("OCR error: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// ===== Validators =====
  String? validatePhone(String? val) {
    if (val == null || val.isEmpty) return "Required";
    String digits = val.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^9\d{9}$').hasMatch(digits)) {
      return "Enter valid 10-digit Nepal phone number";
    }
    return null;
  }

  String? validatePassword(String? val) {
    if (val == null || val.isEmpty) return "Required";
    if (!RegExp(r'[A-Z]').hasMatch(val)) {
      return "Password must contain at least 1 uppercase letter";
    }
    if (!RegExp(r'\d').hasMatch(val)) {
      return "Password must contain at least 1 digit";
    }
    if (val.length < 6) return "Password must be at least 6 characters";
    return null;
  }

  Future<void> registerUser() async {
    if (!formKey.currentState!.validate()) return;

    if (!verificationPassed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please verify citizenship first")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      var uri = Uri.parse(Config.register);
      var request = http.MultipartRequest('POST', uri);

      // -------------------- Fields --------------------
      request.fields['fullname'] = fullName.text.trim();
      request.fields['dob'] = dob.text.trim();
      request.fields['district'] = district.text.trim();
      request.fields['citizen_number'] = citizenNumber.text.trim();
      request.fields['phone'] = phone.text.trim();
      request.fields['password'] = password.text.trim();

      // -------------------- Images --------------------
      if (frontImage != null) {
        String frontBase64 = await convertToBase64(frontImage!);
        request.fields['front_image'] = frontBase64;
      }
      if (backImage != null) {
        String backBase64 = await convertToBase64(backImage!);
        request.fields['back_image'] = backBase64;
      }

      // -------------------- Selfie Image --------------------
      if (kIsWeb && selfieWebImage != null) {
        // Web: selfieWebImage is Uint8List
        String faceBase64 = base64Encode(selfieWebImage!);
        request.fields['face_image'] = faceBase64;
      } else if (!kIsWeb && selfieImage != null) {
        // Mobile: selfieImage is XFile
        String faceBase64 = await convertToBase64(selfieImage!);
        request.fields['face_image'] = faceBase64;
      }

      // -------------------- Send request --------------------
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      var resBody = jsonDecode(response.body);

      // -------------------- Response handling --------------------
      switch (response.statusCode) {
        case 200:
          if (resBody['success'] != null) {
            String message;
            if (resBody['success'] is String) {
              message = resBody['success'];
            } else if (resBody['success'] == true) {
              message = "Registration successful";
            } else {
              message = "Registration failed";
            }

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => LoginPage(showMessage: message),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(resBody['error'] ?? 'Unknown error')),
            );
          }
          break;

        case 409:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(resBody['error'] ?? "Already exists")),
          );
          break;

        case 422:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(resBody['error'] ?? "Invalid input")),
          );
          break;

        default:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Server error ${response.statusCode}")),
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

  /// ===== UI Helpers =====
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
    );
  }

  Widget imagePreview({XFile? img, Uint8List? webImg}) {
    // If Web image exists, show it
    if (kIsWeb && webImg != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          webImg,
          height: 120,
          width: 160,
          fit: BoxFit.cover,
        ),
      );
    }

    // If no image, show placeholder
    if (img == null) {
      return Container(
        height: 120,
        width: 160,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text("No image", style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    // Mobile or Web XFile
    if (kIsWeb) {
      return FutureBuilder<Uint8List>(
        future: img.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                snapshot.data!,
                height: 120,
                width: 160,
                fit: BoxFit.cover,
              ),
            );
          } else {
            return const CircularProgressIndicator(color: Colors.white);
          }
        },
      );
    } else {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(img.path),
          height: 120,
          width: 160,
          fit: BoxFit.cover,
        ),
      );
    }
  }

  @override
  void dispose() {
    fullName.dispose();
    dob.dispose();
    district.dispose();
    citizenNumber.dispose();
    phone.dispose();
    password.dispose();
    super.dispose();
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              padding: const EdgeInsets.all(25),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.white24),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  children: [
                    const Text(
                      "Register",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ================== STEP WIZARD ==================
                    if (currentStep == 0) ...[
                      // Step 1: Personal Info + Citizen Images + Verify
                      TextFormField(
                        controller: fullName,
                        style: const TextStyle(color: Colors.white),
                        decoration: buildInputDecoration("Full Name"),
                        validator: (val) =>
                            val == null || val.isEmpty ? "Required" : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: dob,
                        inputFormatters: [DateFormatter()],
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration:
                            buildInputDecoration("Date of Birth (YYYY-MM-DD)"),
                        validator: (val) =>
                            val == null || val.isEmpty ? "Required" : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: district,
                        style: const TextStyle(color: Colors.white),
                        decoration: buildInputDecoration("District"),
                        validator: (val) =>
                            val == null || val.isEmpty ? "Required" : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: citizenNumber,
                        inputFormatters: [CitizenNumberFormatter()],
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: buildInputDecoration(
                            "Citizen Number (XX-XX-XX-XXXXX)"),
                        validator: (val) =>
                            val == null || val.isEmpty ? "Required" : null,
                        readOnly: true,
                      ),
                      const SizedBox(height: 12),

                      LayoutBuilder(
                        builder: (context, constraints) {
                          double maxWidth = constraints.maxWidth;

                          if (maxWidth < 400) {
                            return Column(
                              children: [
                                imagePreview(img: frontImage),
                                const SizedBox(height: 6),
                                ElevatedButton(
                                    onPressed: () =>
                                        pickImage(true, ImageSource.gallery),
                                    child: const Text("Front Image")),
                                const SizedBox(height: 12),
                                imagePreview(img: backImage),
                                const SizedBox(height: 6),
                                ElevatedButton(
                                    onPressed: () =>
                                        pickImage(false, ImageSource.gallery),
                                    child: const Text("Back Image")),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    imagePreview(img: frontImage),
                                    const SizedBox(height: 6),
                                    ElevatedButton(
                                        onPressed: () => pickImage(
                                            true, ImageSource.gallery),
                                        child: const Text("Front Image")),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  children: [
                                    imagePreview(img: backImage),
                                    const SizedBox(height: 6),
                                    ElevatedButton(
                                        onPressed: () => pickImage(
                                            false, ImageSource.gallery),
                                        child: const Text("Back Image")),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: isLoading ? null : verifyFromImages,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 50, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          verificationPassed ? "Verified ✔" : "Verify",
                          style: TextStyle(
                              color: verificationPassed
                                  ? Colors.greenAccent
                                  : Colors.white),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                          onPressed: verificationPassed
                              ? () => setState(() => currentStep = 1)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 50, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Next",
                            style: TextStyle(
                                color: Color(0xFF4A00E0),
                                fontWeight: FontWeight.bold),
                          )),
                    ],

                    if (currentStep == 1) ...[
                      // Step 2: Phone + Password + Selfie + Register
                      TextFormField(
                        controller: phone,
                        inputFormatters: [PhoneFormatter()],
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white),
                        decoration: buildInputDecoration("Phone Number"),
                        validator: validatePhone,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: password,
                        obscureText: !passwordVisible,
                        style: const TextStyle(color: Colors.white),
                        decoration: buildInputDecoration("Password").copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              passwordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.white70,
                            ),
                            onPressed: () {
                              setState(() {
                                passwordVisible = !passwordVisible;
                              });
                            },
                          ),
                        ),
                        validator: validatePassword,
                      ),
                      const SizedBox(height: 20),
                      Column(
                        children: [
                          imagePreview(
                              img: selfieImage, webImg: selfieWebImage),
                          const SizedBox(height: 6),
                          const Text(
                            "Please take a selfie clearly holding your citizenship card. "
                            "If the image is not clear, it may be rejected by the admin.",
                            style: TextStyle(color: Colors.red, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          ElevatedButton(
                            onPressed: () async {
                              if (kIsWeb) {
                                await takeSelfie();
                              } else {
                                await takeSelfie();
                              }
                            },
                            child: const Text("Take Selfie"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton(
                              onPressed: () => setState(() => currentStep = 0),
                              child: const Text("Back")),
                          ElevatedButton(
                            onPressed: isLoading ? null : registerUser,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 50, vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              isLoading ? "Registering..." : "Register",
                              style: const TextStyle(
                                  color: Color(0xFF4A00E0),
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Already have an account? ",
                          style: TextStyle(color: Colors.white70),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => LoginPage()),
                            );
                          },
                          child: const Text(
                            "Login",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
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
