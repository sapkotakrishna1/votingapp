import 'dart:convert';
import 'package:evoting_app/config.dart';
import 'package:flutter/material.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';

class VotingHomePage extends StatefulWidget {
  final String? loggedCitizenID; // Citizen ID for voting
  final String? loggedDistrict; // District for citizen/admin
  final String? adminPrivateKey; // Admin private key (if admin)

  const VotingHomePage({
    super.key,
    this.loggedCitizenID,
    this.adminPrivateKey,
    this.loggedDistrict,
  });

  @override
  State<VotingHomePage> createState() => _VotingHomePageState();
}

class _VotingHomePageState extends State<VotingHomePage> {
  late Web3Client client;
  late Client httpClient;
  Credentials? credentials;
  late EthereumAddress contractAddress;

  bool votingStarted = false;
  bool isAdmin = false;
  bool isVoting = false;
  String status = "";
  List<Map<String, dynamic>> candidates = [];
  String? selectedDistrict;

  final int chainId = 1337; // Ganache ID
  final TextEditingController candidateController = TextEditingController();

  // ---------------- DISTRICT INFO ----------------
  Map<String, Map<String, String>> districtsInfo = {
    "kathmandu": {
      "contract": "0x3f5F5a5D4d599F835a6f1e83FA31915c42ffF56b",
      "privateKey":
          "0xfcb36bec2706d84f494861724b1becd8957f3f24066dd149bfe9fc079cea08c2"
    },
    "parbat": {
      "contract": "0x60b14A6d6F42EFe3857BaB5b785D19fe8ab78E5f",
      "privateKey":
          "0x83f65474f255542c7e870fa3d72ae7a8752aa5e44aafecf74bcf54c20618b394"
    },
    "baglung": {
      "contract": "0x24c9657C81D29B36Bd194fE3A16Af1F1A1A79987",
      "privateKey":
          "0xfcb36bec2706d84f494861724b1becd8957f3f24066dd149bfe9fc079cea08c2"
    },
    "lalitpur": {
      "contract": "0x24c9657C81D29B36Bd194fE3A16Af1F1A1A79987",
      "privateKey": "0xPRIVATE_KEY4"
    },
    "bhaktapur": {
      "contract": "0x24c9657C81D29B36Bd194fE3A16Af1F1A1A79987",
      "privateKey": "0xPRIVATE_KEY5"
    },
  };

  final String ownerPrivateKey =
      "0xe0939d3655850f97fdf4e9d20acb1aca21c8992227862dcafc64750fe8c07229"; // Deployer account for assignAdmin

  @override
  void initState() {
    super.initState();
    setup();
  }

  // ---------------- SETUP ----------------
  Future<void> setup() async {
    httpClient = Client();
    client = Web3Client("http://localhost:8545", httpClient);

    selectedDistrict = widget.loggedDistrict?.toLowerCase();

    if (selectedDistrict != null &&
        districtsInfo.containsKey(selectedDistrict)) {
      final info = districtsInfo[selectedDistrict]!;

      contractAddress = EthereumAddress.fromHex(info["contract"]!);
      credentials = widget.adminPrivateKey != null
          ? EthPrivateKey.fromHex(widget.adminPrivateKey!)
          : EthPrivateKey.fromHex(info["privateKey"]!);

      status = "Checking admin rights for $selectedDistrict...";

      // Assign admins for all districts (only first time)
      await assignAdminsForAll();

      // Check admin and voting status
      await checkVotingStatus();
      await fetchCandidates();
    } else {
      status = "⚠️ Your district is not added!";
      selectedDistrict = null;
    }

    setState(() {});
  }

  // ---------------- CONTRACT ----------------
  DeployedContract getContract() {
    final abi = ContractAbi.fromJson(
      '''[{"inputs":[{"internalType":"string","name":"_district","type":"string"},{"internalType":"string","name":"_name","type":"string"}],"name":"addCandidate","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"string","name":"_district","type":"string"}],"name":"clearCandidates","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"string","name":"_district","type":"string"}],"name":"startVoting","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"string","name":"_district","type":"string"}],"name":"stopVoting","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"string","name":"_district","type":"string"},{"internalType":"uint256","name":"_candidateId","type":"uint256"},{"internalType":"uint256","name":"_citizenID","type":"uint256"}],"name":"vote","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"string","name":"_district","type":"string"}],"name":"getResultsByDistrict","outputs":[{"internalType":"uint256[]","name":"ids","type":"uint256[]"},{"internalType":"string[]","name":"names","type":"string[]"},{"internalType":"uint256[]","name":"votesList","type":"uint256[]"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"string","name":"_district","type":"string"}],"name":"votingStartedByDistrict","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_admin","type":"address"},{"internalType":"string","name":"_district","type":"string"}],"name":"isAdminOfDistrict","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_admin","type":"address"},{"internalType":"string","name":"_district","type":"string"}],"name":"assignAdmin","outputs":[],"stateMutability":"nonpayable","type":"function"}]''',
      "Voting",
    );
    return DeployedContract(abi, contractAddress);
  }

  // ---------------- ASSIGN ADMINS ----------------
  Future<void> assignAdminsForAll() async {
    try {
      final ownerCred = EthPrivateKey.fromHex(ownerPrivateKey);
      final contract = getContract();

      for (var district in districtsInfo.keys) {
        final adminAddr =
            EthPrivateKey.fromHex(districtsInfo[district]!["privateKey"]!)
                .address;

        await client.sendTransaction(
          ownerCred,
          Transaction.callContract(
            contract: contract,
            function: contract.function("assignAdmin"),
            parameters: [adminAddr, district],
            maxGas: 500000,
          ),
          chainId: chainId,
        );

        print("Assigned $district to admin $adminAddr");
      }
    } catch (e) {
      print("Admin assignment error: $e");
    }
  }

  // ---------------- STATUS CHECK ----------------
  Future<void> checkVotingStatus() async {
    if (selectedDistrict == null || credentials == null) return;

    try {
      final contract = getContract();

      // Voting status
      final votingResult = await client.call(
        contract: contract,
        function: contract.function("votingStartedByDistrict"),
        params: [selectedDistrict],
      );
      votingStarted = votingResult.isNotEmpty ? votingResult[0] as bool : false;

      // Admin check
      final adminResult = await client.call(
        contract: contract,
        function: contract.function("isAdminOfDistrict"),
        params: [credentials!.address, selectedDistrict],
      );
      isAdmin = adminResult.isNotEmpty ? adminResult[0] as bool : false;

      setState(() {});
    } catch (e) {
      setState(() => status = "Error fetching status: $e");
    }
  }

  // ---------------- FETCH CANDIDATES ----------------
  Future<void> fetchCandidates() async {
    if (selectedDistrict == null) return;

    try {
      final contract = getContract();
      final results = await client.call(
        contract: contract,
        function: contract.function("getResultsByDistrict"),
        params: [selectedDistrict],
      );

      if (results.isEmpty ||
          results[0].isEmpty ||
          results[1].isEmpty ||
          results[2].isEmpty) {
        setState(() {
          status = "⏳ Waiting for admin approval...";
          candidates = [];
        });
        return;
      }

      final List ids = results[0];
      final List names = results[1];
      final List votes = results[2];

      candidates = [];

      for (int i = 0; i < ids.length; i++) {
        candidates.add({
          "id": (ids[i] as BigInt).toInt(),
          "name": names[i],
          "voteCount": (votes[i] as BigInt).toInt(),
        });
      }

      setState(() {
        status = "Candidates loaded";
      });
    } catch (e) {
      setState(() => status = "Error loading candidates: $e");
    }
  }

  // ---------------- SAVE RESULTS TO PHP ----------------
  Future<void> saveResultsToPHP() async {
    if (selectedDistrict == null) return;

    final uri = Uri.parse(Config.saveResult);

    final data = {
      "district": selectedDistrict!,
      "results": candidates
          .map((c) => {
                "id": c["id"].toString(),
                "name": c["name"],
                "voteCount": c["voteCount"].toString(),
              })
          .toList(),
    };

    try {
      final response = await httpClient.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        setState(() => status = "📥 Saved results to PHP database!");
      } else {
        setState(() => status = "⚠️ PHP save failed: ${response.body}");
      }
    } catch (e) {
      setState(() => status = "❌ Failed to save results to PHP: $e");
    }
  }

  // ---------------- ADMIN TRANSACTION ----------------
  Future<void> sendTransaction(String fn, List params,
      {bool saveBeforeClear = false}) async {
    if (!isAdmin) {
      setState(() => status = "❌ Not admin of this district");
      return;
    }

    try {
      if (saveBeforeClear) {
        await saveResultsToPHP();
      }

      final contract = getContract();
      final tx = Transaction.callContract(
        contract: contract,
        function: contract.function(fn),
        parameters: params,
        maxGas: 500000,
      );

      await client.sendTransaction(credentials!, tx, chainId: chainId);
      await fetchCandidates();
      await checkVotingStatus();

      setState(() => status = "✅ Success!");
    } catch (e) {
      setState(() => status = "❌ Error: $e");
    }
  }

  // ---------------- CAST VOTE ----------------
  Future<void> castVote(int candidateId) async {
    if (!votingStarted) {
      setState(() => status = "❌ Voting is not live!");
      return;
    }
    if (widget.loggedCitizenID == null) {
      setState(() => status = "❌ Citizen ID missing");
      return;
    }

    final citizenID =
        int.parse(widget.loggedCitizenID!.replaceAll("-", "").trim());

    setState(() {
      status = "Submitting vote...";
      isVoting = true;
    });

    try {
      final tx = Transaction.callContract(
        contract: getContract(),
        function: getContract().function("vote"),
        parameters: [
          selectedDistrict,
          BigInt.from(candidateId),
          BigInt.from(citizenID)
        ],
        maxGas: 200000,
      );

      await client.sendTransaction(credentials!, tx, chainId: chainId);
      await fetchCandidates();

      setState(() {
        status = "✅ Vote submitted!";
        isVoting = false;
      });
    } catch (e) {
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains("already voted") || errorMsg.contains("voted")) {
        setState(() {
          status = "⚠️ Citizen already voted!";
          isVoting = false;
        });
        return;
      }

      setState(() {
        status = "❌ Vote failed: $e";
        isVoting = false;
      });
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Voting DApp")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _infoCard("Logged Citizen", widget.loggedCitizenID ?? "Not Found ❌"),
          const SizedBox(height: 10),
          _infoCard("District", selectedDistrict ?? "Not Assigned ⚠️"),
          const SizedBox(height: 20),
          if (status.isNotEmpty)
            Center(
              child: Text(status,
                  style: const TextStyle(color: Colors.blue, fontSize: 16)),
            ),
          const SizedBox(height: 20),
          if (isAdmin) ..._adminControls(),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                votingStarted
                    ? Icons.circle
                    : Icons.stop_circle, // icon for status
                color: votingStarted
                    ? Colors.green
                    : Colors.red, // icon color only
                size: 24,
              ),
              const SizedBox(width: 8), // spacing between icon and text
              Text(
                votingStarted ? "Voting is LIVE" : "Voting is STOPPED",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  // no color here, keeps default
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          for (var c in candidates)
            Card(
              child: ListTile(
                title: Text(c['name']),
                subtitle: Text("Votes: ${c['voteCount']}"),
                trailing: votingStarted
                    ? ElevatedButton(
                        onPressed: isVoting ? null : () => castVote(c['id']),
                        child: isVoting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text("Vote"),
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.deepPurple.shade100,
          borderRadius: BorderRadius.circular(10)),
      child: Text("$title: $value",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  List<Widget> _adminControls() {
    return [
      TextField(
        controller: candidateController,
        decoration: const InputDecoration(
            labelText: "Candidate Name", border: OutlineInputBorder()),
      ),
      const SizedBox(height: 10),
      ElevatedButton(
        onPressed: !votingStarted && selectedDistrict != null
            ? () => sendTransaction(
                "addCandidate", [selectedDistrict, candidateController.text])
            : null,
        child: const Text("Add Candidate"),
      ),
      const SizedBox(height: 10),
      ElevatedButton(
        onPressed: !votingStarted && selectedDistrict != null
            ? () => sendTransaction("startVoting", [selectedDistrict])
            : null,
        child: const Text("Start Voting"),
      ),
      const SizedBox(height: 10),
      ElevatedButton(
        onPressed: votingStarted && selectedDistrict != null
            ? () => sendTransaction("stopVoting", [selectedDistrict])
            : null,
        child: const Text("Stop Voting"),
      ),
      const SizedBox(height: 10),
      ElevatedButton(
        onPressed: !votingStarted && selectedDistrict != null
            ? () => sendTransaction("clearCandidates", [selectedDistrict],
                saveBeforeClear: true)
            : null,
        child: const Text("Clear & Save Results"),
      ),
    ];
  }
}
