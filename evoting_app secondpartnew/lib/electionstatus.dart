import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';

class ElectionStatusPage extends StatefulWidget {
  final String district;

  const ElectionStatusPage(
      {super.key, required this.district, required String loggedCitizenID});

  @override
  State<ElectionStatusPage> createState() => _ElectionStatusPageState();
}

class _ElectionStatusPageState extends State<ElectionStatusPage>
    with SingleTickerProviderStateMixin {
  late Web3Client client;
  late Client httpClient;
  late EthereumAddress contractAddress;

  List<Map<String, dynamic>> candidates = [];
  bool isLoading = true;
  String status = "";

  final Map<String, String> districtContracts = {
    "parbat": "0xcD1e352D92248df48533b910fb725AE478Ff02fe",
    "pokhara": "0x24c9657C81D29B36Bd194fE3A16Af1F1A1A79987",
    "baglung": "0x24c9657C81D29B36Bd194fE3A16Af1F1A1A79987",
    "lalitpur": "0x24c9657C81D29B36Bd194fE3A16Af1F1A1A79987",
    "bhaktapur": "0x24c9657C81D29B36Bd194fE3A16Af1F1A1A79987",
  };

  late AnimationController winnerAnimation;

  @override
  void initState() {
    super.initState();
    winnerAnimation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
      lowerBound: 0.8,
      upperBound: 1.2,
    )..repeat(reverse: true);

    setup();
  }

  @override
  void dispose() {
    winnerAnimation.dispose();
    super.dispose();
  }

  Future<void> setup() async {
    isLoading = true;
    setState(() {});

    httpClient = Client();
    client = Web3Client("http://localhost:8545", httpClient);

    final key = widget.district.trim().toLowerCase();

    if (!districtContracts.containsKey(key)) {
      status = "District contract not found!";
      isLoading = false;
      setState(() {});
      return;
    }

    contractAddress = EthereumAddress.fromHex(districtContracts[key]!);

    await fetchResults(key);

    isLoading = false;
    setState(() {});
  }

  DeployedContract getContract() {
    final abi = ContractAbi.fromJson(jsonEncode([]), "Voting"); // REPLACE ABI

    return DeployedContract(abi, contractAddress);
  }

  Future<void> fetchResults(String district) async {
    try {
      final contract = getContract();

      final results = await client.call(
        contract: contract,
        function: contract.function("getResultsByDistrict"),
        params: [district],
      );

      final ids = results[0] as List;
      final names = results[1] as List;
      final votes = results[2] as List;

      candidates = List.generate(ids.length, (i) {
        return {
          "id": (ids[i] as BigInt).toInt(),
          "name": names[i],
          "voteCount": (votes[i] as BigInt).toInt(),
        };
      });

      if (candidates.isEmpty) {
        status = "No candidates found!";
      }
    } catch (e) {
      status = "Failed to load results: $e";
    }
  }

  Widget buildPieChart() {
    if (candidates.isEmpty || candidates.every((c) => c["voteCount"] == 0)) {
      return const Text(
        "No votes yet",
        style: TextStyle(color: Colors.white70, fontSize: 18),
      );
    }

    return SizedBox(
      height: 250,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...candidates];
    sorted.sort((a, b) => b["voteCount"].compareTo(a["voteCount"]));
    final winner = sorted.isNotEmpty ? sorted.first : null;

    return Scaffold(
      appBar: AppBar(
        title: Text("Final Results - ${widget.district}"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
          ),
        ),
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : candidates.isEmpty
                ? Center(
                    child: Text(
                      status,
                      style: const TextStyle(color: Colors.white),
                    ),
                  )
                : Column(
                    children: [
                      ScaleTransition(
                        scale: winnerAnimation,
                        child: Column(
                          children: [
                            const Icon(Icons.emoji_events,
                                size: 60, color: Colors.yellow),
                            Text(
                              "Winner: ${winner!['name']}",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "Votes: ${winner['voteCount']}",
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 18),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Pie Chart
                      buildPieChart(),

                      const SizedBox(height: 20),

                      // All candidates
                      Expanded(
                        child: ListView(
                          children: sorted.map((c) {
                            return Container(
                              padding: const EdgeInsets.all(14),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    c['name'],
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    "Votes: ${c['voteCount']}",
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 16),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
