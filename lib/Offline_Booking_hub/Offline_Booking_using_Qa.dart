import 'package:flutter/material.dart';
import 'package:lastmile_transport/Offline_Booking_hub/qr_scanner_screen.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';


class ChatMessage {
  final String text;
  final bool isBot;
  final List<String>? options;


  ChatMessage({required this.text, required this.isBot, this.options});


  Map<String, dynamic> toJson() => {
        'text': text,
        'isBot': isBot,
        'options': options,
      };


  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        text: json['text'],
        isBot: json['isBot'],
        options:
            json['options'] != null ? List<String>.from(json['options']) : null,
      );
}


class EvHubOfflineChatbotScreen extends StatefulWidget {
  const EvHubOfflineChatbotScreen({Key? key}) : super(key: key);


  @override
  _EvHubOfflineChatbotScreenState createState() =>
      _EvHubOfflineChatbotScreenState();
}


class _EvHubOfflineChatbotScreenState extends State<EvHubOfflineChatbotScreen> {
  List<ChatMessage> messages = [];
  final ScrollController _scrollController = ScrollController();


  // App State Data
  double walletBalance = 0.0; // Starts at 0, loaded from global memory
  String savedSource = "AISSMS College";


  final Map<String, Map<String, double>> offlineDestinations = {
    "Pune Station": {"lat": 18.5284, "lng": 73.8739},
    "Shivajinagar": {"lat": 18.5314, "lng": 73.8446},
    "Kothrud": {"lat": 18.5074, "lng": 73.8077},
  };


  String selectedDestination = "";
  String selectedVehicle = "";
  double currentFare = 0.0;


  int conversationStep = 0;
  bool isInitializing = true;


  @override
  void initState() {
    super.initState();
    _initializeAppState();
  }


  // 1. New Initialization Flow
  Future<void> _initializeAppState() async {
    // Load the global wallet first
    await _loadGlobalWallet();
    // Then load the chat history
    await _loadChatHistory();
  }


  // 2. Global Wallet Management
  Future<void> _loadGlobalWallet() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // If it's a brand new app install, give them 250 by default, otherwise load memory
      walletBalance = prefs.getDouble('global_wallet_balance') ?? 250.0;
    });
  }


  Future<void> _saveGlobalWallet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('global_wallet_balance', walletBalance);
  }


  // Add money function
  void _addMoneyToWallet(double amount) {
    setState(() {
      walletBalance += amount;
    });
    _saveGlobalWallet();
  }


  // 3. Chat History Management (Separated from Wallet)
  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? messagesJson = prefs.getString('chat_history');
    final int? savedStep = prefs.getInt('chat_step');


    if (messagesJson != null && savedStep != null) {
      final List<dynamic> decodedList = jsonDecode(messagesJson);
      setState(() {
        messages = decodedList.map((m) => ChatMessage.fromJson(m)).toList();
        conversationStep = savedStep;


        currentFare = prefs.getDouble('current_fare') ?? 0.0;
        selectedDestination = prefs.getString('selected_dest') ?? "";


        isInitializing = false;
      });
      _scrollToBottom();
    } else {
      setState(() {
        isInitializing = false;
      });
      _startConversation();
    }
  }


  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String messagesJson =
        jsonEncode(messages.map((m) => m.toJson()).toList());


    await prefs.setString('chat_history', messagesJson);
    await prefs.setInt('chat_step', conversationStep);
    await prefs.setDouble('current_fare', currentFare);
    await prefs.setString('selected_dest', selectedDestination);
  }


  Future<void> _clearChatHistory() async {
    final prefs = await SharedPreferences.getInstance();


    // Explicitly remove ONLY chat-related keys. DO NOT clear 'global_wallet_balance'
    await prefs.remove('chat_history');
    await prefs.remove('chat_step');
    await prefs.remove('current_fare');
    await prefs.remove('selected_dest');


    setState(() {
      messages.clear();
      conversationStep = 0;
      currentFare = 0.0;
      selectedDestination = "";
    });
    _startConversation();
  }


  void _startConversation() {
    _addBotMessage(
      "Hi! I'm your Offline EV Hub Assistant. 🌿\n\nI see your current location is near $savedSource.",
      options: ["Book a Ride", "Add Money to Wallet"],
    );
  }


  Future<Position?> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;


      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }


      if (permission == LocationPermission.deniedForever) return null;


      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (e) {
      debugPrint("Geolocator Error: $e");
      return null;
    }
  }


  void _handleUserAction(String action) async {
    setState(() {
      messages.add(ChatMessage(text: action, isBot: false));
    });
    _saveChatHistory();
    _scrollToBottom();


    await Future.delayed(const Duration(milliseconds: 600));


    try {
      // Handle global actions regardless of step
      if (action == "Add ₹100 to Wallet" || action == "Add Money to Wallet") {
        _addMoneyToWallet(100.0);


        if (conversationStep == 0) {
          _addBotMessage(
              "✅ Added ₹100 to your wallet. Current Balance: ₹$walletBalance.",
              options: ["Book a Ride"]);
        } else if (conversationStep == 3) {
          // If they added money while trying to pay
          _addBotMessage(
              "✅ Added ₹100. Current Balance: ₹$walletBalance. Would you like to proceed with the payment for ₹$currentFare?",
              options: ["Pay ₹$currentFare from Wallet", "Cancel Booking"]);
        }
        return; // Exit early so state machine doesn't advance
      }


      switch (conversationStep) {
        case 0:
          if (action == "Book a Ride") {
            conversationStep = 1;
            _addBotMessage(
              "Where would you like to go today?",
              options: offlineDestinations.keys.toList(),
            );
          }
          break;


        case 1:
          conversationStep = 2;
          selectedDestination = action;


          _addBotMessage("Checking GPS and calculating distance...");


          Position? currentPosition = await _determinePosition();
          double distInMeters = 0;


          if (!offlineDestinations.containsKey(selectedDestination)) {
            throw Exception("Destination not found in offline data");
          }


          if (currentPosition != null) {
            distInMeters = Geolocator.distanceBetween(
              currentPosition.latitude,
              currentPosition.longitude,
              offlineDestinations[selectedDestination]!["lat"]!,
              offlineDestinations[selectedDestination]!["lng"]!,
            );
          } else {
            distInMeters = Geolocator.distanceBetween(
              18.5303,
              73.8584,
              offlineDestinations[selectedDestination]!["lat"]!,
              offlineDestinations[selectedDestination]!["lng"]!,
            );
          }


          double distanceKm =
              double.parse((distInMeters / 1000).toStringAsFixed(1));


          int scooterPrice = (10 + (distanceKm * 5)).round();
          int bikePrice = (15 + (distanceKm * 7)).round();


          _addBotMessage(
            "Got it! The exact offline distance to $selectedDestination is $distanceKm km.\n\nHere is the price for our EV Hub vehicles:\n\n🔌 EV Scooter: ₹$scooterPrice\n🚲 EV Bike: ₹$bikePrice\n\nPlease select your preferred vehicle:",
            options: ["EV Scooter (₹$scooterPrice)", "EV Bike (₹$bikePrice)"],
          );
          break;


        case 2:
          conversationStep = 3;
          selectedVehicle = action.split(" ")[1];
          String fareStr = action.replaceAll(RegExp(r'[^0-9]'), '');
          currentFare = double.parse(fareStr);


          _addBotMessage(
            "You chose an EV $selectedVehicle. The price is ₹$currentFare.\n\nYour current Wallet Balance is ₹$walletBalance. Proceed with payment?",
            options: ["Pay ₹$currentFare from Wallet", "Cancel Booking"],
          );
          break;


        case 3:
          if (action == "Cancel Booking") {
            _addBotMessage(
                "Booking cancelled. Let me know if you need another ride.",
                options: ["Book a Ride"]);
            conversationStep = 0;
          } else if (action.startsWith("Pay")) {
            if (walletBalance >= currentFare) {
              // Pay the fare and save global wallet instantly
              setState(() {
                walletBalance -= currentFare;
              });
              _saveGlobalWallet();


              conversationStep = 4;
              _addBotMessage(
                "✅ Payment Successful! ₹$currentFare deducted.\n\nYour EV is booked.\n\n⚠️ IMPORTANT: To unlock the vehicle, you need an OTP. The OTP is only valid for 2 minutes. Please click 'Generate OTP' ONLY when you are standing directly in front of the vehicle.",
                options: ["Generate OTP"],
              );
            } else {
              // Insufficient funds flow
              _addBotMessage(
                  "❌ Insufficient wallet balance. You need ₹$currentFare but have ₹$walletBalance.",
                  options: ["Add ₹100 to Wallet", "Cancel Booking"]);
            }
          }
          break;


       case 4:
  if (action == "Generate OTP") {
    conversationStep = 5;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const QrGenerateScreen(data: "offline"),
      ),
    ).then((scannedCode) {
      if (scannedCode != null) {
        _addBotMessage(
          "✅ Vehicle unlocked successfully!\n\nHave a safe ride to $selectedDestination 🌿",
          options: ["End Chat"],
        );
      } else {
        _addBotMessage(
          "QR scan cancelled.",
          options: ["Generate OTP"],
        );
        conversationStep = 4;
      }
    });
  }
  break;


        case 5:
          if (action == "End Chat") {
            _clearChatHistory();
            return;
          }
          break;
      }
    } catch (e) {
      debugPrint("Chatbot State Machine Error: $e");
      _addBotMessage(
          "Sorry, an error occurred while processing that. Let's start over.",
          options: ["Book a Ride"]);
      conversationStep = 0;
    }


    _saveChatHistory();
  }


  void _addBotMessage(String text, {List<String>? options}) {
    setState(() {
      if (messages.isNotEmpty && messages.last.isBot) {
        messages[messages.length - 1] =
            ChatMessage(text: messages.last.text, isBot: true, options: null);
      }
      messages.add(ChatMessage(text: text, isBot: true, options: options));
    });
    _saveChatHistory();
    _scrollToBottom();
  }


  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    if (isInitializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }


    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("EV Hub Assistant",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                "Wallet: ₹$walletBalance",
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _clearChatHistory,
            tooltip: "Reset Chat",
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return _buildChatBubble(messages[index]);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.ev_station, size: 16, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  "Offline EV Booking Enabled",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }


  Widget _buildChatBubble(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment:
            message.isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment:
                message.isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (message.isBot)
                CircleAvatar(
                  backgroundColor: Colors.green.shade700,
                  radius: 16,
                  child: const Icon(Icons.electric_scooter,
                      color: Colors.white, size: 18),
                ),
              if (message.isBot) const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color:
                          message.isBot ? Colors.white : Colors.green.shade600,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: message.isBot
                            ? const Radius.circular(0)
                            : const Radius.circular(16),
                        bottomRight: message.isBot
                            ? const Radius.circular(16)
                            : const Radius.circular(0),
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2))
                      ]),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: message.isBot ? Colors.black87 : Colors.white,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              if (!message.isBot) const SizedBox(width: 8),
              if (!message.isBot)
                CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  radius: 16,
                  child: Icon(Icons.person,
                      color: Colors.green.shade800, size: 18),
                ),
            ],
          ),
          if (message.options != null && message.options!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12.0, left: 40),
              child: Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: message.options!.map((option) {
                  return ActionChip(
                    label: Text(option,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.green.shade50,
                    side: BorderSide(color: Colors.green.shade200),
                    onPressed: () => _handleUserAction(option),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}


