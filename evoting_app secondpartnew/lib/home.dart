import 'dart:convert';
import 'package:evoting_app/UserProfilePage.dart';
import 'package:evoting_app/VotingHistoryPageuser.dart';
import 'package:evoting_app/candidate_detail_page_user.dart';
import 'package:evoting_app/config.dart';
import 'package:evoting_app/electionstatus.dart';
import 'package:evoting_app/login.dart';
import 'package:evoting_app/usernewsui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'uservotingpage.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  final String citizenNumber;
  final String loggedDistrict;

  const HomeScreen({
    super.key,
    required this.username,
    required this.citizenNumber,
    required this.loggedDistrict,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> fadeAnimation;

  List<Map<String, dynamic>> candidates = [];
  bool isLoadingCandidates = true;
  String? userFacePhoto;

  List<NewsItem> allNews = [];
  bool isLoadingNews = true;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
    fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    fetchCandidates();
    fetchUserProfile();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> fetchUserProfile() async {
    try {
      final response = await http.post(
        Uri.parse(Config.getuserprofile),
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {'citizen_number': widget.citizenNumber},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            userFacePhoto = data['face_photo'];
          });
        }
      }
    } catch (e) {
      print("Error fetching user profile: $e");
    }
  }

  // =======================
  // CANDIDATES
  // =======================
  Future<void> fetchCandidates() async {
    try {
      final response = await http.get(Uri.parse(Config.getcandidates));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List fetchedCandidates = data['candidates'] ?? [];

        setState(() {
          candidates = fetchedCandidates
              .where((e) =>
                  e["district"] != null &&
                  e["district"].toString().toLowerCase() ==
                      widget.loggedDistrict.toLowerCase())
              .map<Map<String, dynamic>>((e) => {
                    "id": e["id"],
                    "fullname": e["fullname"],
                    "party": e["party"],
                    "district": e["district"],
                    "address": e["address"],
                    "education": e["education"],
                    "details": e["details"],
                    "dob": e["dob"],
                    "vision": e["vision"],
                    "photo": e["photo"],
                  })
              .toList();

          isLoadingCandidates = false;
        });
      } else {
        isLoadingCandidates = false;
      }
    } catch (e) {
      isLoadingCandidates = false;
    }
  }

  Widget candidateBoxFromData(Map<String, dynamic> candidate) {
    final String? photo = candidate['photo'];

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CandidateDetailPage(candidate: candidate),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: photo != null
                  ? Image.memory(
                      base64Decode(photo.split(',').last),
                      height: 100,
                      width: 100,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      height: 100,
                      width: 100,
                      color: Colors.grey[300],
                      child: const Icon(Icons.person, size: 50),
                    ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(candidate['fullname'] ?? '',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("Party: ${candidate['party'] ?? ''}",
                      style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 6),
                  Text("Tap to view details",
                      style: GoogleFonts.poppins(
                          color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget dashboardCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.15),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.poppins(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: GoogleFonts.poppins(
                          fontSize: 14, color: Colors.white70)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.white70)
          ],
        ),
      ),
    );
  }

  Widget buildNewsModal() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: const Color(0xFF5A1FD6),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 60,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text("Latest News",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4A00E0),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: FadeTransition(
          opacity: fadeAnimation,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PROFILE ROW
                  Row(
                    children: [
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserProfilePage(
                                username: widget.username,
                                citizenNumber: widget.citizenNumber,
                                district: widget.loggedDistrict,
                                facePhoto: userFacePhoto,
                              ),
                            ),
                          );
                        },
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white24,
                          backgroundImage: userFacePhoto != null
                              ? MemoryImage(base64Decode(userFacePhoto!))
                              : null,
                          child: userFacePhoto == null
                              ? const Icon(Icons.person,
                                  size: 35, color: Colors.white)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Welcome",
                              style: GoogleFonts.poppins(
                                  fontSize: 22, color: Colors.white70)),
                          Text(
                            widget.username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),
                  Text("District: ${widget.loggedDistrict}",
                      style: GoogleFonts.poppins(
                          fontSize: 18, color: Colors.white70)),

                  const SizedBox(height: 25),
                  Text("Candidates",
                      style: GoogleFonts.poppins(
                          fontSize: 22,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),

                  const SizedBox(height: 10),
                  isLoadingCandidates
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white))
                      : candidates.isEmpty
                          ? Center(
                              child: Text("No candidates in your district",
                                  style: GoogleFonts.poppins(
                                      color: Colors.white70)),
                            )
                          : Column(
                              children: candidates
                                  .map((c) => candidateBoxFromData(c))
                                  .toList(),
                            ),

                  // NEWS SECTION
                  const SizedBox(height: 25),
                  dashboardCard(
                    title: "News & Updates",
                    subtitle: "View latest election & national news",
                    icon: Icons.newspaper,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NewsPage()),
                      );
                    },
                  ),

                  dashboardCard(
                    title: "Vote Now",
                    subtitle: "Cast your vote securely",
                    icon: Icons.how_to_vote,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserVotingPage(
                            loggedCitizenID: widget.citizenNumber,
                            district: widget.loggedDistrict,
                          ),
                        ),
                      );
                    },
                  ),
                  dashboardCard(
                    title: "Election Status",
                    subtitle: "Check whether voting is ongoing",
                    icon: Icons.event_available,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ElectionStatusPage(
                            loggedCitizenID: widget.citizenNumber,
                            district: widget.loggedDistrict,
                          ),
                        ),
                      );
                    },
                  ),
                  dashboardCard(
                    title: "Live Results",
                    subtitle: "View real-time vote counting",
                    icon: Icons.bar_chart,
                    onTap: () {},
                  ),
                  dashboardCard(
                    title: "Voting History",
                    subtitle: "See your previous voting records",
                    icon: Icons.history,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VotingHistoryPage(
                            district: widget.loggedDistrict,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 30),
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                          (route) => false,
                        );
                      },
                      child: const Text("Logout"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NewsItem {
  final String title;
  final String description;
  final String url;
  final String source;

  NewsItem({
    required this.title,
    required this.description,
    required this.url,
    required this.source,
  });
}
