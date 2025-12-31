import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

class VotingHistoryPage extends StatefulWidget {
  final String district;

  const VotingHistoryPage({super.key, required this.district});

  @override
  State<VotingHistoryPage> createState() => _VotingHistoryPageState();
}

class _VotingHistoryPageState extends State<VotingHistoryPage> {
  Map<String, List<dynamic>> results = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchResults();
  }

  Future<void> fetchResults() async {
    try {
      final response = await http.post(
        Uri.parse(Config.getElectionResults),
        body: {
          "district": widget.district,
        },
      );

      debugPrint("STATUS: ${response.statusCode}");
      debugPrint("BODY: ${response.body}");

      if (response.body.isEmpty) {
        throw Exception("Empty response from server");
      }

      final data = jsonDecode(response.body);

      setState(() {
        isLoading = false;
        if (data['success'] == true) {
          results = Map<String, List<dynamic>>.from(data['results']);
        }
      });
    } catch (e) {
      debugPrint("Error fetching results: $e");
      setState(() => isLoading = false);
    }
  }

  Widget glassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: child,
    );
  }

  Widget resultCard(Map<String, dynamic> candidate) {
    return glassCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            candidate['name'],
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            candidate['votes'].toString(),
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4A00E0),
      appBar: AppBar(
        title: const Text("Voting History"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : results.isEmpty
                ? Center(
                    child: Text(
                      "No results available",
                      style: GoogleFonts.poppins(color: Colors.white70),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: results.entries.map((entry) {
                        final date = entry.key;
                        final candidates = entry.value;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Election Date: $date",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...candidates
                                .map((c) => resultCard(
                                      Map<String, dynamic>.from(c),
                                    ))
                                .toList(),
                            const SizedBox(height: 20),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
      ),
    );
  }
}
