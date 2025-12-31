import 'package:evoting_app/config.dart';
import 'package:evoting_app/login.dart';
import 'package:evoting_app/votinghomepage.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'CandidateManagementScreen.dart';

class AdminHomeScreen extends StatefulWidget {
  final String username;
  final String citizenNumber;
  final String district;

  const AdminHomeScreen({
    super.key,
    required this.username,
    required this.citizenNumber,
    required this.district,
  });

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> users = [];
  bool isLoadingUsers = true;

  // Dashboard stats
  int totalUsers = 0;
  int approvedUsers = 0;
  int pendingUsers = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    fetchUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> fetchUsers() async {
    try {
      final response = await http.get(Uri.parse(Config.getusers));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List fetchedUsers = data["users"];

        // Filter users by admin district
        final filteredUsers = fetchedUsers.where((user) {
          return user["district"] == widget.district;
        }).toList();

        setState(() {
          users = filteredUsers
              .map<Map<String, dynamic>>((e) => {
                    "fullname": e["fullname"],
                    "citizen_number": e["citizen_number"],
                    "dob": e["dob"],
                    "district": e["district"],
                    "phone": e["phone"],
                    "front_image": e["front_image"],
                    "back_image": e["back_image"],
                    "face_photo": e["face_photo"],
                    "approved": e["approved"] == null
                        ? null
                        : int.parse(e["approved"].toString()),
                  })
              .toList();

          totalUsers = users.length;
          approvedUsers =
              users.where((u) => u['approved'] == 1).toList().length;
          pendingUsers =
              users.where((u) => u['approved'] == null).toList().length;

          isLoadingUsers = false;
        });
      } else {
        setState(() => isLoadingUsers = false);
      }
    } catch (e) {
      setState(() => isLoadingUsers = false);
      print("Error fetching users: $e");
    }
  }

  Widget buildBase64Image(String? base64Data, {double? height}) {
    if (base64Data == null || base64Data.isEmpty) {
      return Container(
        height: height ?? 120,
        color: Colors.grey[300],
        child: const Center(child: Icon(Icons.broken_image, size: 40)),
      );
    }

    try {
      final cleaned =
          base64Data.contains(',') ? base64Data.split(',').last : base64Data;
      final bytes = base64Decode(cleaned);
      return Image.memory(
        bytes,
        height: height ?? 120,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    } catch (_) {
      return Container(
        height: height ?? 120,
        color: Colors.grey[300],
        child: const Center(child: Icon(Icons.broken_image, size: 40)),
      );
    }
  }

  void showFullImage(String? base64Data) {
    if (base64Data == null || base64Data.isEmpty) return;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: Colors.black,
            padding: const EdgeInsets.all(8),
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 2.5,
              child: buildBase64Image(base64Data, height: 300),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> approveUser(String citizenNumber) async {
    final response = await http.post(
      Uri.parse(Config.approveUser),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"citizen_number": citizenNumber, "approved": 1}),
    );
    if (response.statusCode == 200) {
      fetchUsers();
    }
  }

  Future<void> rejectUser(String citizenNumber) async {
    final response = await http.post(
      Uri.parse(Config.approveUser),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"citizen_number": citizenNumber, "approved": 0}),
    );
    if (response.statusCode == 200) {
      fetchUsers();
    }
  }

  Widget buildFaceAvatar(String? base64Data, {required int size}) {
    if (base64Data == null || base64Data.isEmpty) {
      return const CircleAvatar(
        radius: 28,
        backgroundColor: Colors.grey,
        child: Icon(Icons.person, color: Colors.white),
      );
    }

    try {
      final cleaned =
          base64Data.contains(',') ? base64Data.split(',').last : base64Data;
      final bytes = base64Decode(cleaned);

      return CircleAvatar(
        radius: 28,
        backgroundImage: MemoryImage(bytes),
        backgroundColor: Colors.transparent,
      );
    } catch (_) {
      return const CircleAvatar(
        radius: 28,
        backgroundColor: Colors.grey,
        child: Icon(Icons.person, color: Colors.white),
      );
    }
  }

  void showEditUserDialog(Map<String, dynamic> user) {
    final fullnameController = TextEditingController(text: user['fullname']);
    final citizenController =
        TextEditingController(text: user['citizen_number']);
    final districtController = TextEditingController(text: user['district']);
    final dobController = TextEditingController(text: user['dob']);
    final phoneController = TextEditingController(text: user['phone']);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 12,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Modern title with color
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Colors.blue, Colors.lightBlueAccent]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      "Edit User Details",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Full Name
                TextField(
                  controller: fullnameController,
                  decoration: InputDecoration(
                    labelText: "Full Name",
                    filled: true,
                    fillColor: Colors.grey[200],
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.blue)),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                // Citizen Number
                TextField(
                  controller: citizenController,
                  decoration: InputDecoration(
                    labelText: "Citizen Number",
                    filled: true,
                    fillColor: Colors.grey[200],
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.blue)),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                // District
                TextField(
                  controller: districtController,
                  decoration: InputDecoration(
                    labelText: "District",
                    filled: true,
                    fillColor: Colors.grey[200],
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.blue)),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                // DOB
                TextField(
                  controller: dobController,
                  decoration: InputDecoration(
                    labelText: "DOB (YYYY-MM-DD)",
                    filled: true,
                    fillColor: Colors.grey[200],
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.blue)),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                // Phone
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: "Phone",
                    filled: true,
                    fillColor: Colors.grey[200],
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.blue)),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: const Text("Cancel"),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final response = await http.post(
                          Uri.parse(Config.updateuser),
                          headers: {"Content-Type": "application/json"},
                          body: jsonEncode({
                            "citizen_number": citizenController.text,
                            "fullname": fullnameController.text,
                            "district": districtController.text,
                            "dob": dobController.text,
                            "phone": phoneController.text,
                          }),
                        );

                        if (response.statusCode == 200) {
                          fetchUsers();
                          Navigator.pop(context);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Failed to update user")),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("Save"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildUserCard(Map<String, dynamic> user) {
    return Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => showFullImage(user['face_photo']),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white54, width: 2),
                    ),
                    child: buildFaceAvatar(user['face_photo'], size: 56),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    user['fullname'] ?? '',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text("Citizen: ${user['citizen_number'] ?? ''}",
                style: const TextStyle(color: Colors.white70)),
            Text("DOB: ${user['dob'] ?? ''}",
                style: const TextStyle(color: Colors.white70)),
            Text("District: ${user['district'] ?? ''}",
                style: const TextStyle(color: Colors.white70)),
            Text("Phone: ${user['phone'] ?? ''}",
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => showFullImage(user['front_image']),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: buildBase64Image(user['front_image'], height: 140),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => showFullImage(user['back_image']),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: buildBase64Image(user['back_image'], height: 140),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (user['approved'] == null) ...[
                  ElevatedButton.icon(
                    onPressed: () => approveUser(user['citizen_number']),
                    icon: const Icon(Icons.check),
                    label: const Text("Approve"),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => rejectUser(user['citizen_number']),
                    icon: const Icon(Icons.close),
                    label: const Text("Reject"),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ] else if (user['approved'] == 1) ...[
                  const Text(
                    "Approved",
                    style: TextStyle(
                        color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => showEditUserDialog(user),
                    icon: const Icon(Icons.edit),
                    label: const Text("Edit"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent),
                  ),
                ] else if (user['approved'] == 0) ...[
                  const Text(
                    "Rejected",
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget gradientButton(
          String text, IconData icon, List<Color> colors, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
              Text(text,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ],
          ),
        ),
      );

  Widget buildStatCard(String title, int count, IconData icon, Color color) {
    return Flexible(
      fit: FlexFit.tight,
      child: Container(
        margin: const EdgeInsets.all(4), // smaller margin
        padding: const EdgeInsets.all(12), // smaller padding
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.7), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 4),
            Text(
              "$count",
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(title,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Welcome, ${widget.username} (${widget.district})",
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                        (route) => false,
                      );
                    },
                  )
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              tabs: const [
                Tab(icon: Icon(Icons.people), text: "Users"),
                Tab(icon: Icon(Icons.how_to_vote), text: "Candidates"),
                Tab(icon: Icon(Icons.bar_chart), text: "Voting"),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  isLoadingUsers
                      ? const Center(child: CircularProgressIndicator())
                      : Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              SizedBox(
                                height: 150,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    buildStatCard("Total Users", totalUsers,
                                        Icons.people, Colors.blue),
                                    buildStatCard("Approved", approvedUsers,
                                        Icons.check, Colors.green),
                                    buildStatCard("Pending", pendingUsers,
                                        Icons.hourglass_empty, Colors.orange),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: users.length,
                                  itemBuilder: (context, index) {
                                    return buildUserCard(users[index]);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                  CandidateManagementScreen(
                    loggedCitizenID: widget.citizenNumber,
                    loggedDistrict: widget.district,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        gradientButton(
                          "Start Voting",
                          Icons.play_arrow,
                          [Colors.greenAccent, Colors.green],
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => VotingHomePage(
                                        loggedCitizenID: widget.citizenNumber,
                                        loggedDistrict: widget.district,
                                      )),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
