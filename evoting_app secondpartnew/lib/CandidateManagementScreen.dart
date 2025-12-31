import 'package:evoting_app/CandidateDetailsScreen.dart';
import 'package:evoting_app/config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'dart:html' as html;

class CandidateManagementScreen extends StatefulWidget {
  final String loggedCitizenID;
  final String loggedDistrict;

  const CandidateManagementScreen(
      {super.key, required this.loggedCitizenID, required this.loggedDistrict});

  @override
  State<CandidateManagementScreen> createState() =>
      _CandidateManagementScreenState();
}

class _CandidateManagementScreenState extends State<CandidateManagementScreen> {
  List<Map<String, dynamic>> candidates = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchCandidates();
  }

  Future<void> fetchCandidates() async {
    try {
      final response = await http.get(Uri.parse(Config.getCandidates));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List fetchedCandidates = data['candidates'] ?? [];
        setState(() {
          candidates = fetchedCandidates
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
              .where((c) => c['district'] == widget.loggedDistrict)
              .toList();
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
      print("Error fetching: $e");
    }
  }

  Widget candidateCard(Map<String, dynamic> candidate) {
    Widget buildPhoto(String? base64Photo) {
      if (base64Photo == null || base64Photo.isEmpty) {
        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.person, size: 60, color: Colors.white70),
        );
      }
      try {
        Uint8List imageBytes = base64Decode(base64Photo);
        return GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => Dialog(
                backgroundColor: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Image.memory(imageBytes, fit: BoxFit.contain),
                ),
              ),
            );
          },
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: MemoryImage(imageBytes),
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      } catch (e) {
        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(12),
          ),
          child:
              const Icon(Icons.broken_image, size: 60, color: Colors.white70),
        );
      }
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CandidateDetailsScreen(candidate: candidate),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        color: Colors.white.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildPhoto(candidate['photo']),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(candidate['fullname'] ?? '',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 4),
                    Text("Address: ${candidate['address'] ?? ''}",
                        style: const TextStyle(color: Colors.white70)),
                    Text("Party: ${candidate['party'] ?? ''}",
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Manage Candidates"),
          backgroundColor: Colors.deepPurple,
          actions: [
            IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => AddEditCandidateScreen(
                                  adminDistrict: widget.loggedDistrict)))
                      .then((_) => fetchCandidates());
                })
          ],
        ),
        backgroundColor: Colors.black,
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: candidates.length,
                itemBuilder: (context, index) {
                  return candidateCard(candidates[index]);
                },
              ));
  }
}

// ------------------- Add/Edit Candidate Screen -------------------

class AddEditCandidateScreen extends StatefulWidget {
  final Map<String, dynamic>? candidate;
  final String? adminDistrict;

  const AddEditCandidateScreen({super.key, this.candidate, this.adminDistrict});

  @override
  State<AddEditCandidateScreen> createState() => _AddEditCandidateScreenState();
}

class _AddEditCandidateScreenState extends State<AddEditCandidateScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController fullname = TextEditingController();
  final TextEditingController citizenNumber =
      TextEditingController(); // <-- Added
  final TextEditingController party = TextEditingController();
  final TextEditingController district = TextEditingController();
  final TextEditingController dob = TextEditingController();
  final TextEditingController education = TextEditingController();
  final TextEditingController vision = TextEditingController();
  final TextEditingController details = TextEditingController();
  final TextEditingController address = TextEditingController();

  String? _base64Photo;
  Uint8List? _webImageBytes;

  @override
  void initState() {
    super.initState();

    if (widget.candidate != null) {
      fullname.text = widget.candidate!['fullname'] ?? '';
      citizenNumber.text =
          widget.candidate!['citizen_number'] ?? ''; // <-- Added
      party.text = widget.candidate!['party'] ?? '';
      district.text =
          widget.candidate!['district'] ?? widget.adminDistrict ?? '';
      dob.text = widget.candidate!['dob'] ?? '';
      education.text = widget.candidate!['education'] ?? '';
      vision.text = widget.candidate!['vision'] ?? '';
      details.text = widget.candidate!['details'] ?? '';
      address.text = widget.candidate!['address'] ?? '';
      _base64Photo = widget.candidate!['photo'];
      if (kIsWeb && _base64Photo != null) {
        _webImageBytes = base64Decode(_base64Photo!);
      }
    } else {
      district.text = widget.adminDistrict ?? '';
    }
  }

  Future<void> pickPhoto() async {
    if (kIsWeb) {
      final input = html.FileUploadInputElement()..accept = 'image/*';
      input.click();
      input.onChange.listen((event) async {
        if (input.files!.isNotEmpty) {
          final file = input.files!.first;
          final reader = html.FileReader();
          reader.readAsArrayBuffer(file);
          reader.onLoadEnd.listen((event) {
            final bytes = reader.result as Uint8List;
            setState(() {
              _webImageBytes = bytes;
              _base64Photo = base64Encode(bytes);
            });
          });
        }
      });
    } else {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.gallery);
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _base64Photo = base64Encode(bytes);
        });
      }
    }
  }

  Future<void> saveCandidate() async {
    if (!_formKey.currentState!.validate()) return;
    final isEdit = widget.candidate != null;
    final url = isEdit ? Config.editCandidateM : Config.addCandidate;

    final Map<String, String> body = {
      "fullname": fullname.text.trim(),
      "citizen_number": citizenNumber.text.trim(), // <-- Added
      "party": party.text.trim(),
      "district": district.text.trim(),
      "dob": dob.text.trim(),
      "education": education.text.trim(),
      "vision": vision.text.trim(),
      "details": details.text.trim(),
      "address": address.text.trim(),
      if (_base64Photo != null) "photo": _base64Photo!,
      if (isEdit) "id": widget.candidate!['id'].toString(),
    };

    try {
      final response = await http.post(Uri.parse(url), body: body);
      final data = jsonDecode(response.body);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(data['message'] ?? '')));
      if (data['status'] == 'success') Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Widget buildTextField(String label, TextEditingController controller,
      {int maxLines = 1, bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        readOnly: readOnly,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.white30),
              borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.deepPurple),
              borderRadius: BorderRadius.circular(12)),
        ),
        validator: (v) => v == null || v.isEmpty ? "Required" : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title:
            Text(widget.candidate != null ? "Edit Candidate" : "Add Candidate"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              buildTextField("Full Name", fullname),
              buildTextField("Citizen Number", citizenNumber), // <-- Added
              buildTextField("Party", party),
              buildTextField("District", district,
                  readOnly: true), // Admin district, read-only
              buildTextField("Address", address),
              buildTextField("DOB (YYYY-MM-DD)", dob),
              buildTextField("Education", education),
              buildTextField("Vision", vision),
              buildTextField("Details", details, maxLines: 3),
              const SizedBox(height: 10),
              if (_webImageBytes != null)
                Image.memory(_webImageBytes!, height: 150, fit: BoxFit.cover),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: pickPhoto,
                icon: const Icon(Icons.photo),
                label: const Text("Select Photo"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: saveCandidate,
                child: Text(widget.candidate != null ? "Update" : "Add"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
