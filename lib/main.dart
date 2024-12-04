import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase
  runApp( ChatPage());
}

// Chat List Page
class ChatPage extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

   ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('ChatMessages').orderBy('last_time', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final chats = snapshot.data!.docs;

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index].data() as Map<String, dynamic>;

              return ListTile(
                leading: CircleAvatar(
                  child: Text(chat['to_name'][0].toUpperCase()),
                ),
                title: Text(chat['to_name'] ?? 'Unknown'),
                subtitle: Text(chat['last_msg'] ?? 'No messages yet'),
                trailing: Text(
                  chat['last_time'] != null
                      ? (chat['last_time'] as Timestamp).toDate().toString()
                      : '',
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatThreadDetailsPage(
                        chatId: chats[index].id,
                        toName: chat['to_name'],
                        toUid: chat['to_uid'],
                        fromUid: chat['from_uid'],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// Chat Thread Details Page
class ChatThreadDetailsPage extends StatefulWidget {
  final String chatId;
  final String toName;
  final String toUid;
  final String fromUid;

  const ChatThreadDetailsPage({
    super.key,
    required this.chatId,
    required this.toName,
    required this.toUid,
    required this.fromUid,
  });

  @override
  _ChatThreadDetailsPageState createState() => _ChatThreadDetailsPageState();
}

class _ChatThreadDetailsPageState extends State<ChatThreadDetailsPage> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = {
      'content': _messageController.text,
      'from_uid': widget.fromUid,
      'to_uid': widget.toUid,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
      'status': 'sent',
    };

    // Add message to the `messages` sub-collection
    await _firestore
        .collection('ChatMessages')
        .doc(widget.chatId)
        .collection('messages')
        .add(message);

    // Update the main chat document with the last message details
    await _firestore.collection('ChatMessages').doc(widget.chatId).update({
      'last_msg': _messageController.text,
      'last_time': FieldValue.serverTimestamp(),
    });

    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.toName),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('ChatMessages')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data() as Map<String, dynamic>;
                    final isSentByUser = message['from_uid'] == widget.fromUid;

                    return Align(
                      alignment: isSentByUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: isSentByUser ? Colors.blue[300] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(message['content'] ?? ''),
                            const SizedBox(height: 5),
                            Text(
                              message['timestamp'] != null
                                  ? (message['timestamp'] as Timestamp).toDate().toString()
                                  : 'Sending...',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
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
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
