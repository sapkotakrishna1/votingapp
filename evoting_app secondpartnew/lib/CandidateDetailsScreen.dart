import 'package:evoting_app/config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
//import 'CandidateManagementScreen.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class CandidateDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> candidate;
  const CandidateDetailsScreen({super.key, required this.candidate});

  @override
  State<CandidateDetailsScreen> createState() => _CandidateDetailsScreenState();
}

class _CandidateDetailsScreenState extends State<CandidateDetailsScreen> {
  Uint8List? imageBytes;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController fullname;
  late TextEditingController party;
  late TextEditingController district;
  late TextEditingController dob;
  late TextEditingController education;
  late TextEditingController vision;
  late TextEditingController details;
  late TextEditingController address;

  String? _base64Photo;
  bool isEditing = false;

  @override
  void initState() {
    super.initState();
    fullname = TextEditingController(text: widget.candidate['fullname'] ?? '');
    party = TextEditingController(text: widget.candidate['party'] ?? '');
    district = TextEditingController(text: widget.candidate['district'] ?? '');
    dob = TextEditingController(text: widget.candidate['dob'] ?? '');
    education =
        TextEditingController(text: widget.candidate['education'] ?? '');
    vision = TextEditingController(text: widget.candidate['vision'] ?? '');
    details = TextEditingController(text: widget.candidate['details'] ?? '');
    address = TextEditingController(text: widget.candidate['address'] ?? '');
    _base64Photo = widget.candidate['photo'];

    if (_base64Photo != null) {
      try {
        imageBytes = base64Decode(_base64Photo!);
      } catch (_) {}
    }
  }

  Future<void> deleteCandidate() async {
    try {
      final response = await http.post(
        Uri.parse("${Config.baseUrl}/deletecandidates.php"),
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: {
          'id': widget.candidate['id'].toString(),
        },
      );

      final data = jsonDecode(response.body);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? "Unknown response")),
      );

      if (response.statusCode == 200 && data['success'] == true) {
        // Go back to previous screen
        Navigator.pop(context, true); // triggers reload
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Future<void> saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final body = {
      'id': widget.candidate['id'].toString(),
      'fullname': fullname.text,
      'party': party.text,
      'district': district.text,
      'dob': dob.text,
      'education': education.text,
      'vision': vision.text,
      'details': details.text,
      'address': address.text,
      'photo': _base64Photo ?? '',
    };

    try {
      final response = await http.post(
        Uri.parse(Config.editCandidate),
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: body,
      );

      final data = jsonDecode(response.body);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? 'Update complete')),
      );

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() => isEditing = false);

        // Optional: go back and refresh list
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.candidate['fullname'] ?? "Candidate Details"),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.close : Icons.edit),
            onPressed: () {
              setState(() {
                isEditing = !isEditing;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Confirm Delete"),
                  content: const Text(
                      "Are you sure you want to delete this candidate?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context); // close dialog
                        await deleteCandidate(); // now delete + go back
                      },
                      child: const Text(
                        "Delete",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          )
        ],
      ),
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (imageBytes != null)
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      backgroundColor: Colors.transparent,
                      child: Image.memory(imageBytes!, fit: BoxFit.contain),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child:
                      Image.memory(imageBytes!, height: 250, fit: BoxFit.cover),
                ),
              ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildTextField(fullname, "Full Name"),
                  _buildTextField(party, "Party"),
                  _buildTextField(dob, "DOB"),
                  _buildTextField(education, "Education"),
                  _buildTextField(vision, "Vision"),
                  _buildTextField(details, "Details"),
                  _buildTextField(address, "Address"),
                  if (isEditing) const SizedBox(height: 16),
                  if (isEditing)
                    ElevatedButton(
                      onPressed: saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text("Save Changes"),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        enabled: isEditing,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white70)),
          focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.deepPurple)),
        ),
        validator: (value) =>
            value == null || value.isEmpty ? "Required" : null,
      ),
    );
  }
}
