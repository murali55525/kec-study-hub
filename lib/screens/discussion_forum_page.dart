import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


class DiscussionForumPage extends StatefulWidget {
  const DiscussionForumPage({super.key});


  @override
  State<DiscussionForumPage> createState() => _DiscussionForumPageState();
}


class _DiscussionForumPageState extends State<DiscussionForumPage>
    with SingleTickerProviderStateMixin {
  String? userEmail;
  String? userDepartment;
  bool isLoading = true;
  late TabController _tabController;


  List<Map<String, dynamic>> _globalMessages = [];
  List<Map<String, dynamic>> _departmentMessages = [];
  final TextEditingController _messageController = TextEditingController();


  final Color globalCommunityColor = Colors.blue.shade100;
  final Color eceCommunityColor = Colors.green.shade100;
  final Color defaultCommunityColor = Colors.grey.shade100;


  final String _baseUrl = 'http://localhost:5000/api/messages';


  // Chatbot-related variables
  final TextEditingController _chatController = TextEditingController();
  List<Map<String, String>> _chatMessages = [];
  bool _isChatLoading = false;


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }


  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _chatController.dispose();
    super.dispose();
  }


  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('userEmail') ?? '';
      print('Loaded email from SharedPreferences: $email');


      final department = _extractDepartment(email);


      setState(() {
        userEmail = email;
        userDepartment = department;
        isLoading = false;
      });


      await _fetchMessages();
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        userEmail = '';
        userDepartment = null;
        isLoading = false;
      });
    }
  }


  String? _extractDepartment(String email) {
    final regex = RegExp(r'\.(\d{2}[a-z]+)@kongu\.edu');
    final match = regex.firstMatch(email);
    if (match != null) {
      final deptCode = match.group(1)?.toLowerCase();
      print('Department code from email: $deptCode');
      if (deptCode != null) {
        if (deptCode.contains('cse')) return 'CSE';
        if (deptCode.contains('eer')) return 'EEE';
        if (deptCode.contains('ecr')) return 'ECE';
        if (deptCode.contains('mer')) return 'MECH';
        if (deptCode.contains('cir')) return 'CIVIL';
      }
    }
    return null;
  }


  Future<void> _fetchMessages() async {
    if (userEmail!.isEmpty) return;


    try {
      final globalResponse = await http.get(Uri.parse('$_baseUrl/global'));
      print(
          'Global response: ${globalResponse.statusCode} - ${globalResponse.body}');
      if (globalResponse.statusCode == 200) {
        setState(() {
          _globalMessages =
              List<Map<String, dynamic>>.from(jsonDecode(globalResponse.body));
        });
      }


      if (userDepartment != null) {
        final deptResponse =
            await http.get(Uri.parse('$_baseUrl/department/$userDepartment'));
        print(
            'Dept response: ${deptResponse.statusCode} - ${deptResponse.body}');
        if (deptResponse.statusCode == 200) {
          setState(() {
            _departmentMessages =
                List<Map<String, dynamic>>.from(jsonDecode(deptResponse.body));
          });
        }
      }
    } catch (e) {
      print('Error fetching messages: $e');
    }
  }


  Future<void> _sendMessage(String message, bool isGlobal) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender': userEmail ?? 'Anonymous',
          'content': message,
          'isGlobal': isGlobal,
        }),
      );


      if (response.statusCode == 200) {
        await _fetchMessages();
        _messageController.clear();
      } else {
        print('Failed to send message: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message.')),
        );
      }
    } catch (e) {
      print('Error in _sendMessage: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('An error occurred while sending the message.')),
      );
    }
  }


  // Chatbot-related methods
  Future<void> _sendChatMessage(String message) async {
    if (message.isEmpty) return;


    setState(() {
      _chatMessages.add({'role': 'user', 'message': message});
      _isChatLoading = true;
    });


    try {
      final response = await http.post(
        Uri.parse('http://localhost:5000/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': message}),
      );


      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final reply = responseData['reply'];
        setState(() {
          _chatMessages.add({'role': 'bot', 'message': reply});
        });
      } else {
        throw Exception('Failed to fetch response');
      }
    } catch (e) {
      setState(() {
        _chatMessages.add(
            {'role': 'bot', 'message': 'Error: Unable to fetch response.'});
      });
    } finally {
      setState(() {
        _isChatLoading = false;
      });
    }
  }


  void _openChatBotDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Chatbot', style: GoogleFonts.poppins()),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _chatMessages.length,
                    itemBuilder: (context, index) {
                      final chat = _chatMessages[index];
                      return Align(
                        alignment: chat['role'] == 'user'
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: chat['role'] == 'user'
                                ? Colors.blue.shade100
                                : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            chat['message']!,
                            style: GoogleFonts.poppins(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_isChatLoading)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
                TextField(
                  controller: _chatController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () {
                        _sendChatMessage(_chatController.text);
                        _chatController.clear();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close', style: GoogleFonts.poppins()),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFF00246B))),
      );
    }


    return Scaffold(
      appBar: AppBar(
        title: Text('Discussion Forum', style: GoogleFonts.poppins()),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.poppins(),
          indicatorColor: const Color(0xFFCADCFC),
          tabs: [
            const Tab(text: 'Global Community'),
            Tab(
              text: userDepartment != null
                  ? '$userDepartment Community'
                  : 'Your Community',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGlobalCommunity(),
          _buildDepartmentCommunity(),
        ],
      ),
      bottomSheet: _buildMessageInput(),
      floatingActionButton: FloatingActionButton(
        onPressed: _openChatBotDialog,
        child: const Icon(Icons.chat),
      ),
    );
  }


  Widget _buildGlobalCommunity() {
    if (userEmail!.isEmpty) {
      return Center(
        child: Text(
          'Please log in to access the Global Community.',
          style:
              GoogleFonts.poppins(fontSize: 18, color: const Color(0xFF00246B)),
        ),
      );
    }


    return Container(
      color: globalCommunityColor,
      child: _globalMessages.isEmpty
          ? Center(
              child: Text(
                'No messages yet.',
                style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _globalMessages.length,
              itemBuilder: (context, index) {
                final message = _globalMessages[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title:
                        Text(message['content'], style: GoogleFonts.poppins()),
                    subtitle: Text(
                      'From: ${message['sender']} • ${DateTime.parse(message['timestamp']).toLocal().toString().substring(0, 16)}',
                      style:
                          GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
    );
  }


  Widget _buildDepartmentCommunity() {
    const communities = ['CSE', 'MECH', 'CIVIL', 'ECE', 'EEE'];


    if (userEmail!.isEmpty) {
      return Center(
        child: Text(
          'Please log in to access your department community.',
          style:
              GoogleFonts.poppins(fontSize: 18, color: const Color(0xFF00246B)),
        ),
      );
    }


    if (userDepartment == null || !communities.contains(userDepartment)) {
      return Center(
        child: Text(
          'No specific community available for your department ($userEmail).',
          style:
              GoogleFonts.poppins(fontSize: 18, color: const Color(0xFF00246B)),
        ),
      );
    }


    return Container(
      color:
          userDepartment == 'ECE' ? eceCommunityColor : defaultCommunityColor,
      child: _departmentMessages.isEmpty
          ? Center(
              child: Text(
                'No messages yet.',
                style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _departmentMessages.length,
              itemBuilder: (context, index) {
                final message = _departmentMessages[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title:
                        Text(message['content'], style: GoogleFonts.poppins()),
                    subtitle: Text(
                      'From: ${message['sender']} • ${DateTime.parse(message['timestamp']).toLocal().toString().substring(0, 16)}',
                      style:
                          GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
    );
  }


  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () {
              if (_messageController.text.isNotEmpty) {
                _sendMessage(
                    _messageController.text, _tabController.index == 0);
              }
            },
          ),
        ],
      ),
    );
  }
}