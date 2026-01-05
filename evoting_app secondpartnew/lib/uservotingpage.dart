import 'dart:convert';
import 'package:evoting_app/passwordconfirm.dart';
import 'package:flutter/material.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';

class UserVotingPage extends StatefulWidget {
  final String loggedCitizenID;
  final String district;

  const UserVotingPage({
    super.key,
    required this.loggedCitizenID,
    required this.district,
  });

  @override
  State<UserVotingPage> createState() => _UserVotingPageState();
}

class _UserVotingPageState extends State<UserVotingPage> {
  late Web3Client client;
  late Client httpClient;
  late Credentials credentials;
  late EthereumAddress contractAddress;

  List<Map<String, dynamic>> candidates = [];
  bool votingStarted = false;
  bool isVoting = false;
  bool hasVoted = false; // new state for citizen vote
  String status = "";

  final int chainId = 1337;

  final Map<String, String> districtContracts = {
    "parbat": "0x60b14A6d6F42EFe3857BaB5b785D19fe8ab78E5f",
    "pokhara": "0x24c9657C81D29B36Bd194fE3A16Af1F1A1A79987",
    "baglung": "0x24c9657C81D29B36Bd194fE3A16Af1F1A1A79987",
    "lalitpur": "0x24c9657C81D29B36Bd194fE3A16Af1F1A1A79987",
    "bhaktapur": "0x24c9657C81D29B36Bd194fE3A16Af1F1A1A79987",
  };

  final String adminPrivateKey =
      "0x83f65474f255542c7e870fa3d72ae7a8752aa5e44aafecf74bcf54c20618b394";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await setup();
    });
  }

  Future<void> setup() async {
    httpClient = Client();
    client = Web3Client("http://localhost:8545", httpClient);
    credentials = EthPrivateKey.fromHex(adminPrivateKey);

    final districtKey = widget.district.trim().toLowerCase();

    if (districtContracts.containsKey(districtKey)) {
      contractAddress =
          EthereumAddress.fromHex(districtContracts[districtKey]!);

      await fetchVotingState(districtKey);
      await fetchCandidates(districtKey);
      hasVoted = await checkIfVoted(districtKey, widget.loggedCitizenID);

      setState(() {});
    } else {
      setState(() => status = "⚠️ District contract not found!");
    }
  }

  DeployedContract getContract() {
    final abi = ContractAbi.fromJson(
        jsonEncode([
          {
            "inputs": [
              {
                "internalType": "string",
                "name": "ownerDistrict",
                "type": "string"
              }
            ],
            "stateMutability": "nonpayable",
            "type": "constructor"
          },
          {
            "anonymous": false,
            "inputs": [
              {
                "indexed": false,
                "internalType": "address",
                "name": "admin",
                "type": "address"
              },
              {
                "indexed": false,
                "internalType": "string",
                "name": "district",
                "type": "string"
              }
            ],
            "name": "AdminAssigned",
            "type": "event"
          },
          {
            "anonymous": false,
            "inputs": [
              {
                "indexed": false,
                "internalType": "string",
                "name": "district",
                "type": "string"
              },
              {
                "indexed": false,
                "internalType": "uint256",
                "name": "id",
                "type": "uint256"
              },
              {
                "indexed": false,
                "internalType": "string",
                "name": "name",
                "type": "string"
              }
            ],
            "name": "CandidateAdded",
            "type": "event"
          },
          {
            "anonymous": false,
            "inputs": [
              {
                "indexed": false,
                "internalType": "string",
                "name": "district",
                "type": "string"
              }
            ],
            "name": "CandidatesCleared",
            "type": "event"
          },
          {
            "anonymous": false,
            "inputs": [
              {
                "indexed": false,
                "internalType": "string",
                "name": "district",
                "type": "string"
              },
              {
                "indexed": false,
                "internalType": "uint256",
                "name": "candidateId",
                "type": "uint256"
              },
              {
                "indexed": false,
                "internalType": "uint256",
                "name": "citizenID",
                "type": "uint256"
              }
            ],
            "name": "Voted",
            "type": "event"
          },
          {
            "anonymous": false,
            "inputs": [
              {
                "indexed": false,
                "internalType": "string",
                "name": "district",
                "type": "string"
              }
            ],
            "name": "VotingStarted",
            "type": "event"
          },
          {
            "anonymous": false,
            "inputs": [
              {
                "indexed": false,
                "internalType": "string",
                "name": "district",
                "type": "string"
              }
            ],
            "name": "VotingStopped",
            "type": "event"
          },
          {
            "inputs": [
              {"internalType": "string", "name": "_district", "type": "string"},
              {"internalType": "string", "name": "_name", "type": "string"}
            ],
            "name": "addCandidate",
            "outputs": [],
            "stateMutability": "nonpayable",
            "type": "function"
          },
          {
            "inputs": [
              {"internalType": "address", "name": "", "type": "address"}
            ],
            "name": "adminDistrict",
            "outputs": [
              {"internalType": "string", "name": "", "type": "string"}
            ],
            "stateMutability": "view",
            "type": "function"
          },
          {
            "inputs": [
              {"internalType": "address", "name": "_admin", "type": "address"},
              {"internalType": "string", "name": "_district", "type": "string"}
            ],
            "name": "assignAdmin",
            "outputs": [],
            "stateMutability": "nonpayable",
            "type": "function"
          },
          {
            "inputs": [
              {"internalType": "string", "name": "_district", "type": "string"}
            ],
            "name": "clearCandidates",
            "outputs": [],
            "stateMutability": "nonpayable",
            "type": "function"
          },
          {
            "inputs": [
              {"internalType": "string", "name": "_district", "type": "string"}
            ],
            "name": "getResultsByDistrict",
            "outputs": [
              {"internalType": "uint256[]", "name": "ids", "type": "uint256[]"},
              {"internalType": "string[]", "name": "names", "type": "string[]"},
              {
                "internalType": "uint256[]",
                "name": "votesList",
                "type": "uint256[]"
              }
            ],
            "stateMutability": "view",
            "type": "function"
          },
          {
            "inputs": [
              {"internalType": "string", "name": "_district", "type": "string"},
              {
                "internalType": "uint256",
                "name": "_citizenID",
                "type": "uint256"
              }
            ],
            "name": "hasCitizenVoted",
            "outputs": [
              {"internalType": "bool", "name": "", "type": "bool"}
            ],
            "stateMutability": "view",
            "type": "function"
          },
          {
            "inputs": [
              {"internalType": "address", "name": "_admin", "type": "address"},
              {"internalType": "string", "name": "_district", "type": "string"}
            ],
            "name": "isAdminOfDistrict",
            "outputs": [
              {"internalType": "bool", "name": "", "type": "bool"}
            ],
            "stateMutability": "view",
            "type": "function"
          },
          {
            "inputs": [],
            "name": "owner",
            "outputs": [
              {"internalType": "address", "name": "", "type": "address"}
            ],
            "stateMutability": "view",
            "type": "function"
          },
          {
            "inputs": [
              {"internalType": "string", "name": "_district", "type": "string"}
            ],
            "name": "startVoting",
            "outputs": [],
            "stateMutability": "nonpayable",
            "type": "function"
          },
          {
            "inputs": [
              {"internalType": "string", "name": "_district", "type": "string"}
            ],
            "name": "stopVoting",
            "outputs": [],
            "stateMutability": "nonpayable",
            "type": "function"
          },
          {
            "inputs": [
              {"internalType": "string", "name": "_district", "type": "string"},
              {
                "internalType": "uint256",
                "name": "_candidateId",
                "type": "uint256"
              },
              {
                "internalType": "uint256",
                "name": "_citizenID",
                "type": "uint256"
              }
            ],
            "name": "vote",
            "outputs": [],
            "stateMutability": "nonpayable",
            "type": "function"
          },
          {
            "inputs": [
              {"internalType": "string", "name": "_district", "type": "string"}
            ],
            "name": "votingStartedByDistrict",
            "outputs": [
              {"internalType": "bool", "name": "", "type": "bool"}
            ],
            "stateMutability": "view",
            "type": "function"
          }
        ]),
        "Voting");

    return DeployedContract(abi, contractAddress);
  }

  Future<void> fetchVotingState(String district) async {
    final contract = getContract();
    final districtParam = district.trim().toLowerCase();

    try {
      final votingResult = await client.call(
        contract: contract,
        function: contract.function("votingStartedByDistrict"),
        params: [districtParam],
      );
      votingStarted = votingResult.isNotEmpty ? votingResult[0] as bool : false;
    } catch (e) {
      votingStarted = false;
      print("Voting check failed: $e");
    }

    setState(() {});
  }

  Future<void> fetchCandidates(String district) async {
    final contract = getContract();
    final districtParam = district.trim().toLowerCase();

    try {
      final results = await client.call(
        contract: contract,
        function: contract.function("getResultsByDistrict"),
        params: [districtParam],
      );

      if (results.isEmpty || (results[0] as List).isEmpty) {
        candidates = [];
        status = "No candidates available";
      } else {
        final ids = results[0] as List;
        final names = results[1] as List;
        final votes = results[2] as List;

        candidates = List.generate(ids.length, (i) {
          return {
            "id": (ids[i] as BigInt).toInt(),
            "name": names[i] as String,
            "voteCount": (votes[i] as BigInt).toInt(),
          };
        });
        status = "";
      }
    } catch (e) {
      candidates = [];
      status = "Failed to fetch candidates: $e";
      print("Fetch candidates failed: $e");
    }

    setState(() {});
  }

  Future<bool> checkIfVoted(String district, String citizenID) async {
    final contract = getContract();
    final citizenBigInt = BigInt.parse(citizenID.replaceAll("-", ""));
    final districtParam = district.trim().toLowerCase();

    try {
      final result = await client.call(
        contract: contract,
        function: contract.function("hasCitizenVoted"),
        params: [districtParam, citizenBigInt],
      );

      return result.isNotEmpty ? result[0] as bool : false;
    } catch (e) {
      print("Check voted failed: $e");
      return false;
    }
  }

  Future<void> castVote(int candidateId) async {
    if (!votingStarted) {
      setState(() => status = "⚠️ Voting has not started!");
      return;
    }

    setState(() {
      isVoting = true;
      status = "Submitting vote...";
    });

    try {
      final citizenID =
          BigInt.parse(widget.loggedCitizenID.replaceAll("-", ""));
      final contract = getContract();
      final district = widget.district.trim().toLowerCase();

      final tx = Transaction.callContract(
        contract: contract,
        function: contract.function("vote"),
        parameters: [district, BigInt.from(candidateId), citizenID],
        maxGas: 200000,
      );

      await client.sendTransaction(credentials, tx, chainId: chainId);

      setState(() {
        status = "✅ Vote submitted successfully!";
        hasVoted = true;
      });
      await fetchCandidates(district);
      await fetchVotingState(district);
    } catch (e) {
      setState(() => status = "❌ Vote failed: $e");
    } finally {
      setState(() => isVoting = false);
    }
  }

  Widget glassCard({required Widget child}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purpleAccent.withOpacity(0.25),
            Colors.deepPurple.withOpacity(0.15)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Vote in ${widget.district}"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: candidates.isEmpty
            ? Center(
                child: Text(
                  status.isEmpty
                      ? "No election is ongoing for your district"
                      : status,
                  style: const TextStyle(fontSize: 18, color: Colors.white70),
                ),
              )
            : Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        votingStarted ? Icons.how_to_vote : Icons.block,
                        color: votingStarted ? Colors.blue : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        votingStarted ? "Voting is LIVE" : "Voting is STOPPED",
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      children: candidates.map((c) {
                        return glassCard(
                          child: ListTile(
                            title: Text(
                              c['name'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            trailing: votingStarted
                                ? hasVoted
                                    ? const Text(
                                        "✅ Already Voted",
                                        style: TextStyle(
                                          color: Colors.greenAccent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : ElevatedButton(
                                        onPressed: isVoting
                                            ? null
                                            : () async {
                                                // 🔐 Ask password using the new page
                                                bool ok =
                                                    await PasswordConfirmationPage
                                                        .show(
                                                            context,
                                                            widget
                                                                .loggedCitizenID);

                                                if (!ok) {
                                                  setState(() {
                                                    status =
                                                        "❌ Wrong password!";
                                                  });
                                                  return;
                                                }

                                                await castVote(c[
                                                    'id']); // 🗳️ blockchain vote
                                              },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.purpleAccent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: isVoting
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Text(
                                                "Vote",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                      )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      !votingStarted
                          ? "⚠️ Voting has not started!"
                          : hasVoted
                              ? "You have already voted."
                              : status,
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
