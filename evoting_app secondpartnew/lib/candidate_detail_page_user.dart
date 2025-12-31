import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CandidateDetailPage extends StatelessWidget {
  final Map<String, dynamic> candidate;

  const CandidateDetailPage({super.key, required this.candidate});

  @override
  Widget build(BuildContext context) {
    final String? photo = candidate['photo'];

    return Scaffold(
      backgroundColor: const Color(0xFF4A00E0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Candidate Details",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ================= PHOTO =================
              GestureDetector(
                onTap: () => _showFullImage(context, photo),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.6),
                      width: 3,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 110,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: photo != null
                        ? MemoryImage(
                            base64Decode(photo.split(',').last),
                          )
                        : null,
                    child: photo == null
                        ? const Icon(Icons.person, size: 80)
                        : null,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ================= NAME =================
              Text(
                candidate['fullname'] ?? '',
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 6),

              Text(
                "Party: ${candidate['party'] ?? '-'}",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),

              const SizedBox(height: 25),

              // ================= INFO =================
              _infoCard("Date of Birth", candidate['dob']),
              _infoCard("Education", candidate['education']),
              _infoCard("Vision", candidate['vision']),
              _infoCard("Details", candidate['details']),
            ],
          ),
        ),
      ),
    );
  }

  // ================= INFO CARD =================
  Widget _infoCard(String title, String? value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value ?? '-',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ================= FULL IMAGE VIEW =================
  void _showFullImage(BuildContext context, String? photo) {
    if (photo == null) return;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 3,
              child: Image.memory(
                base64Decode(photo.split(',').last),
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
