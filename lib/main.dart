import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart'; // For copying to clipboard
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Chat App',
      home: const ChatHomePage(),
    );
  }
}

class ChatHomePage extends StatefulWidget {
  const ChatHomePage({super.key});

  @override
  _ChatHomePageState createState() => _ChatHomePageState();
}

class _ChatHomePageState extends State<ChatHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _tabController.index == 0 ? 'Private Chats' : 'Forum',
        ),
        backgroundColor: Colors.lightBlue,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ChatPage(),
          const ForumPage(),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.lightBlue,
        child: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.message), text: 'Private Chats'),
            Tab(icon: Icon(Icons.forum), text: 'Forum'),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[300],
          indicatorColor: Colors.white,
          indicatorSize: TabBarIndicatorSize.tab,
        ),
      ),
    );
  }
}

class ChatPage extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ChatPage({super.key});

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final messageDate = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(messageDate).inDays;

    if (difference == 0) {
      return DateFormat.jm().format(messageDate);
    } else if (difference == 1) {
      return "Yesterday";
    } else {
      return DateFormat.yMMMd().format(messageDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('ChatMessages')
          .orderBy('last_time', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final chats = snapshot.data!.docs;

        return ListView.separated(
          itemCount: chats.length,
          separatorBuilder: (context, index) {
            return const Divider(
              thickness: 1.0,
              height: 1.0,
              color: Colors.grey,
            );
          },
          itemBuilder: (context, index) {
            final chat = chats[index].data() as Map<String, dynamic>;

            return ListTile(
              leading: CircleAvatar(
                child: Text(chat['to_name'][0].toUpperCase()),
              ),
              title: Text(chat['to_name'] ?? 'Unknown'),
              subtitle: Text(chat['last_msg'] ?? 'No messages yet'),
              trailing: Text(
                formatTimestamp(chat['last_time']),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.blueGrey,
                ),
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
    );
  }
}

class ForumPage extends StatefulWidget {
  const ForumPage({super.key});

  @override
  _ForumPageState createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _postController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        //title: const Text('Forum'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddPostDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('ForumPosts').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final posts = snapshot.data!.docs;

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index].data() as Map<String, dynamic>;
              final postId = posts[index].id;
              final username = post['username'] ?? 'Anonymous';

              return GestureDetector(
                onLongPress: () => _showPostMenu(context, postId),
                child: Card(
                  margin: const EdgeInsets.all(8.0),
                  child: ListTile(
                    title: Text(post['title'] ?? 'No Title'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post['content'] ?? 'No Content'),
                        const SizedBox(height: 4),
                        Text(
                          'Posted by: $username',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PostDetailsPage(postId: postId, postTitle: post['title']),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddPostDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create a New Post'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _postController,
                decoration: const InputDecoration(
                  hintText: 'Enter your post content...',
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (_postController.text.trim().isNotEmpty) {
                  await _firestore.collection('ForumPosts').add({
                    'title': 'New Post', // You can customize this
                    'content': _postController.text,
                    'username': 'CurrentUser', // Replace with actual username
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                  _postController.clear();
                  Navigator.pop(context);
                }
              },
              child: const Text('Post'),
            ),
          ],
        );
      },
    );
  }

  void _showPostMenu(BuildContext context, String postId) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete Post'),
              onTap: () async {
                Navigator.pop(context); // Close the menu
                await _firestore.collection('ForumPosts').doc(postId).delete();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy Post'),
              onTap: () {
                final post = _firestore.collection('ForumPosts').doc(postId).get();
                post.then((value) {
                  if (value.exists) {
                    Clipboard.setData(ClipboardData(text: value['content']));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Post copied to clipboard!')),
                    );
                  }
                });
                Navigator.pop(context); // Close the menu
              },
            ),
            ListTile(
              leading: const Icon(Icons.translate),
              title: const Text('Translate Post'),
              onTap: () {
                Navigator.pop(context); // Placeholder for translation logic
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Translate feature coming soon!')),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class PostDetailsPage extends StatelessWidget {
  final String postId;
  final String postTitle;

  const PostDetailsPage({super.key, required this.postId, required this.postTitle});

  @override
  Widget build(BuildContext context) {
    final TextEditingController _commentController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: Text(postTitle),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('ForumPosts')
                  .doc(postId)
                  .collection('comments')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final comments = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index].data() as Map<String, dynamic>;
                    final username = comment['username'] ?? 'Anonymous';
                    final taggedUser = comment['taggedUser'];
                    final isReply = comment['isReply'] ?? false;

                    return GestureDetector(
                      onLongPress: () => _showCommentMenu(context, comments[index].reference),
                      child: Container(
                        margin: EdgeInsets.only(left: isReply ? 16.0 : 0),
                        child: ListTile(
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (taggedUser != null)
                                Text(
                                  'Replying to @$taggedUser',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue,
                                  ),
                                ),
                              Text(comment['content'] ?? 'No Content'),
                            ],
                          ),
                          subtitle: Text(
                            'Posted by: $username • ${comment['timestamp'] != null ? DateFormat.yMMMd().add_jm().format((comment['timestamp'] as Timestamp).toDate()) : 'No Date'}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.reply),
                            onPressed: () {
                              _commentController.text = '@$username ';
                              FocusScope.of(context).requestFocus(FocusNode());
                            },
                          ),
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
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (value) async {
                      if (value.trim().isNotEmpty) {
                        final taggedUser = value.contains('@')
                            ? value.split('@')[1].split(' ')[0]
                            : null;

                        await FirebaseFirestore.instance
                            .collection('ForumPosts')
                            .doc(postId)
                            .collection('comments')
                            .add({
                          'content': value,
                          'username': 'CurrentUser', // Replace with actual username
                          'taggedUser': taggedUser,
                          'isReply': taggedUser != null,
                          'timestamp': FieldValue.serverTimestamp(),
                        });
                        _commentController.clear();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCommentMenu(BuildContext context, DocumentReference commentRef) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete Comment'),
              onTap: () async {
                Navigator.pop(context); // Close the menu
                await commentRef.delete(); // Delete the comment
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy Comment'),
              onTap: () {
                commentRef.get().then((value) {
                  if (value.exists) {
                    Clipboard.setData(ClipboardData(text: value['content']));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Comment copied to clipboard!')),
                    );
                  }
                });
                Navigator.pop(context); // Close the menu
              },
            ),
            ListTile(
              leading: const Icon(Icons.translate),
              title: const Text('Translate Comment'),
              onTap: () {
                Navigator.pop(context); // Placeholder for translation logic
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Translate feature coming soon!')),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
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
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  String? _audioPath;

  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  bool _isPlaying = false;
  Duration _playbackDuration = Duration.zero;
  Duration _totalDuration = Duration.zero;
  Timer? _playbackTimer;

  @override
  void initState() {
    super.initState();
    _player.openPlayer();
    _recorder.openRecorder();
    Permission.microphone.request();
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _player.closePlayer();
    _recordingTimer?.cancel();
    _playbackTimer?.cancel();
    super.dispose();
  }

  void _showMessageMenu(
      BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> message) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete Message'),
              onTap: () async {
                Navigator.pop(context); // Close the menu
                await message.reference.delete(); // Delete the message
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy Message'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message['content']));
                Navigator.pop(context); // Close the menu
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message copied to clipboard!')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.translate),
              title: const Text('Translate Message'),
              onTap: () {
                Navigator.pop(context); // Placeholder for translation logic
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Translate feature coming soon!')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _openFile(String url) async {
    try {
      // Check if the file is an image
      if (url.toLowerCase().endsWith('.jpg') ||
          url.toLowerCase().endsWith('.jpeg') ||
          url.toLowerCase().endsWith('.png') ||
          url.toLowerCase().endsWith('.gif') ||
          url.toLowerCase().endsWith('.bmp') ||
          url.toLowerCase().endsWith('.webp')) {
        // For images, open directly in a new dialog or page
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              child: Container(
                padding: const EdgeInsets.all(8.0),
                child: Image.network(url),
              ),
            );
          },
        );
      } else {
        // For other files, download and open them
        final file = await _downloadFile(url);
        if (file != null) {
          OpenFile.open(file.path);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to open file')),
          );
        }
      }
    } catch (e) {
      print('Error opening file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to open file')),
      );
    }
  }

  Future<File?> _downloadFile(String url) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${url.split('/').last}');

      // Check if the file already exists
      if (await file.exists()) {
        return file;
      }

      // Download the file if it doesn't exist
      final response = await HttpClient().getUrl(Uri.parse(url));
      final bytes = await consolidateHttpClientResponseBytes(await response.close());
      await file.writeAsBytes(bytes);

      return file;
    } catch (e) {
      print('Error downloading file: $e');
      return null;
    }
  }

  Future<void> _playAudio(String url) async {
    try {
      if (_isPlaying) {
        await _player.stopPlayer();
        setState(() {
          _isPlaying = false;
          _playbackDuration = Duration.zero;
        });
        _playbackTimer?.cancel();
      } else {
        await _player.startPlayer(
          fromURI: url,
          codec: Codec.aacADTS,
          whenFinished: () {
            setState(() {
              _isPlaying = false;
              _playbackDuration = Duration.zero;
            });
            _playbackTimer?.cancel();
          },
        );

        setState(() {
          _isPlaying = true;
        });

        _playbackTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
          final progress = await _player.getProgress();
          setState(() {
            _playbackDuration = progress['currentPosition'] ?? Duration.zero;
            _totalDuration = progress['duration'] ?? Duration.zero;
          });
        });
      }
    } catch (e) {
      print('Error playing audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to play audio')),
      );
    }
  }

  Future<void> _startRecording() async {
    try {
      final status = await Permission.microphone.request();
      if (status.isGranted) {
        final dir = await getApplicationDocumentsDirectory();
        _audioPath = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.aac';
        await _recorder.startRecorder(toFile: _audioPath, codec: Codec.aacADTS);

        setState(() {
          _isRecording = true;
          _recordingDuration = Duration.zero;
        });

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordingDuration += const Duration(seconds: 1);
          });
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
    } catch (e) {
      print('Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start recording')),
      );
    }
  }

  Future<void> _stopRecordingAndUpload() async {
    if (_recorder.isRecording) {
      _recordingTimer?.cancel();
      await _recorder.stopRecorder();

      setState(() {
        _isRecording = false;
        _recordingDuration = Duration.zero;
      });

      if (_audioPath != null) {
        final file = File(_audioPath!);

        // Check if the file exists
        if (!await file.exists()) {
          print('Error: Audio file does not exist at $_audioPath');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Audio file not found')),
          );
          return;
        }

        final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.aac';
        final storagePath = 'chat_files/${widget.chatId}/audio/$fileName';

        try {
          // Upload the audio file to Firebase Storage
          final storageRef = FirebaseStorage.instance.ref().child(storagePath);
          final uploadTask = storageRef.putFile(
            file,
            SettableMetadata(contentType: 'audio/aac'), // Set MIME type
          );

          // Monitor upload progress
          uploadTask.snapshotEvents.listen((taskSnapshot) {
            print('Upload progress: ${taskSnapshot.bytesTransferred / taskSnapshot.totalBytes}');
          });

          // Wait for the upload to complete
          await uploadTask;

          // Get the download URL
          final fileUrl = await storageRef.getDownloadURL();
          print('Audio uploaded successfully. Download URL: $fileUrl');

          // Add the audio message to Firestore
          await _firestore
              .collection('ChatMessages')
              .doc(widget.chatId)
              .collection('messages')
              .add({
            'from_uid': widget.fromUid,
            'to_uid': widget.toUid,
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'audio',
            'file_url': fileUrl,
            'status': 'sent',
          });

          // Update the last message in the chat thread
          await _firestore.collection('ChatMessages').doc(widget.chatId).update({
            'last_msg': 'Voice message',
            'last_time': FieldValue.serverTimestamp(),
          });

          // Clear the audio path
          setState(() {
            _audioPath = null;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Voice recording sent!'),
            ),
          );
        } catch (e) {
          print('Error uploading audio: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload audio')),
          );
        }
      } else {
        print('Error: _audioPath is null');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No audio file to upload')),
        );
      }
    }
  }
  Future<void> _attachFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;

      final mimeType = result.files.single.extension?.toLowerCase();
      final isImage = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(mimeType);

      final storagePath = isImage
          ? 'chat_files/${widget.chatId}/images/$fileName'
          : 'chat_files/${widget.chatId}/files/$fileName';

      try {
        final storageRef = FirebaseStorage.instanceFor(bucket: 'gs://mhealth-6191e.appspot.com')
            .ref()
            .child(storagePath);
        final uploadTask = await storageRef.putFile(file);
        final fileUrl = await uploadTask.ref.getDownloadURL();

        await _firestore
            .collection('ChatMessages')
            .doc(widget.chatId)
            .collection('messages')
            .add({
          'from_uid': widget.fromUid,
          'to_uid': widget.toUid,
          'timestamp': FieldValue.serverTimestamp(),
          'type': isImage ? 'image' : 'file',
          'file_url': fileUrl,
          'file_name': fileName,
          'status': 'sent',
        });
      } catch (e) {
        print('Error uploading file: $e');
      }
    }
  }

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

    await _firestore
        .collection('ChatMessages')
        .doc(widget.chatId)
        .collection('messages')
        .add(message);

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
        backgroundColor: Colors.lightBlue,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection('ChatMessages')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isSentByUser = message['from_uid'] == widget.fromUid;

                    return GestureDetector(
                      onLongPress: () => _showMessageMenu(context, message),
                      child: Align(
                        alignment: isSentByUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8.0, vertical: 4.0),
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: isSentByUser
                                ? Colors.blue[300]
                                : Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (message['type'] == 'text') ...[
                                Text(message['content'] ?? ''),
                              ] else if (message['type'] == 'file') ...[
                                Text('📎 File: ${message['file_name']}'),
                                GestureDetector(
                                  onTap: () {
                                    _openFile(message['file_url']);
                                  },
                                  child: Text(
                                    message['file_url'],
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ] else if (message['type'] == 'audio') ...[
                                Text('🎙 Voice message'),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(_isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow),
                                      onPressed: () =>
                                          _playAudio(message['file_url']),
                                    ),
                                    Expanded(
                                      child: Slider(
                                        value: _playbackDuration.inSeconds
                                            .toDouble(),
                                        min: 0,
                                        max: _totalDuration.inSeconds.toDouble(),
                                        onChanged: (value) {
                                          _player.seekToPlayer(
                                              Duration(seconds: value.toInt()));
                                        },
                                      ),
                                    ),
                                    Text(
                                      '${_playbackDuration.inSeconds}/${_totalDuration.inSeconds}s',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ] else if (message['type'] == 'image') ...[
                                GestureDetector(
                                  onTap: () {
                                    _openFile(message['file_url']);
                                  },
                                  child: Image.network(
                                    message['file_url'],
                                    width: 150,
                                    height: 150,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 5),
                              Text(
                                message['timestamp'] != null
                                    ? DateFormat.jm().format(
                                  (message['timestamp'] as Timestamp)
                                      .toDate(),
                                )
                                    : 'Sending...',
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
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
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: _attachFile,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                if (_isRecording)
                  Text(
                    '${_recordingDuration.inSeconds}s',
                    style: const TextStyle(color: Colors.red),
                  ),
                GestureDetector(
                  onTap: _startRecording,
                  onLongPress: () async {
                    await _stopRecordingAndUpload();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Voice recording sent!'),
                      ),
                    );
                  },
                  child: Icon(
                    Icons.mic,
                    color: _isRecording ? Colors.red : Colors.blue,
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