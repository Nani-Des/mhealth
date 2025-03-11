import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HospitalProfileScreen extends StatefulWidget {
  final String hospitalId;

  const HospitalProfileScreen({Key? key, required this.hospitalId}) : super(key: key);

  @override
  State<HospitalProfileScreen> createState() => _HospitalProfileScreenState();
}

class _HospitalProfileScreenState extends State<HospitalProfileScreen> {
  double _hospitalRating = 0.0; // User's selected rating
  double _averageRating = 0.0; // Hospital's average rating (based on last 20)
  int _ratingCount = 0; // Total number of ratings
  bool _hasRated = false; // Tracks if user has already rated
  bool _isLoading = true; // Tracks initial data loading
  final TextEditingController _reviewController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

 @override
 void initState() {
   super.initState();
   _loadInitialData();
 }

  // Load initial data (check rating status and fetch average/count)
  Future<void> _loadInitialData() async {
    await _checkIfUserHasRated();
    await _fetchRatingData();
    setState(() {
      _isLoading = false;
    });
  }

  // Check if the current user has already rated this hospital
  Future<void> _checkIfUserHasRated() async {
    if (_currentUserId == null) return;

    final ratingDoc = await FirebaseFirestore.instance
        .collection('Hospital')
        .doc(widget.hospitalId)
        .collection('Ratings')
        .doc(_currentUserId)
        .get();

    if (ratingDoc.exists) {
      setState(() {
        _hasRated = true;
        _hospitalRating = ratingDoc['rating'] as double;
      });
    }
  }

  // Fetch the average rating (last 20) and total rating count
  Future<void> _fetchRatingData() async {
    // Get the most recent 20 ratings
    final ratingsSnapshot = await FirebaseFirestore.instance
        .collection('Hospital')
        .doc(widget.hospitalId)
        .collection('Ratings')
        .orderBy('timestamp', descending: true) // Most recent first
        .limit(20) // Only the last 20 ratings
        .get();

    // Calculate average from the last 20 ratings
    if (ratingsSnapshot.docs.isNotEmpty) {
      double total = 0.0;
      for (var doc in ratingsSnapshot.docs) {
        total += doc['rating'] as double;
      }
      _averageRating = total / ratingsSnapshot.docs.length;
    } else {
      _averageRating = 0.0; // No ratings yet
    }

    // Get the total rating count from the parent document
    final hospitalRef =
    FirebaseFirestore.instance.collection('Hospital').doc(widget.hospitalId);
    final hospitalDoc = await hospitalRef.get();

    if (hospitalDoc.exists) {
      // Safely access ratingCount, default to 0 if missing
      final ratingCountValue = hospitalDoc.data()?['ratingCount'];
      _ratingCount = (ratingCountValue is int) ? ratingCountValue : 0;
    } else {
      // Initialize document if it doesn't exist
      await hospitalRef.set({
        'ratingCount': 0,
        'averageRating': 0.0,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _ratingCount = 0;
      _averageRating = 0.0;
    }
  }

  // Submit the user's rating to Firestore
  Future<void> _submitRating(double rating) async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to rate this hospital')),
      );
      return;
    }

    if (_hasRated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have already rated this hospital')),
      );
      return;
    }

    // Reference to the Ratings subcollection
    final ratingsRef = FirebaseFirestore.instance
        .collection('Hospital')
        .doc(widget.hospitalId)
        .collection('Ratings')
        .doc(_currentUserId);

    // Reference to the parent Hospital document
    final hospitalRef =
    FirebaseFirestore.instance.collection('Hospital').doc(widget.hospitalId);

    // Submit the rating
    await ratingsRef.set({
      'rating': rating,
      'timestamp': FieldValue.serverTimestamp(),
      'userId': _currentUserId,
    });

    // Update the hospital's metadata
    await _fetchRatingData(); // Recalculate average from last 20
    final newCount = _ratingCount + 1;

    await hospitalRef.update({
      'ratingCount': newCount,
      'averageRating': _averageRating, // Store the average of last 20
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    setState(() {
      _hasRated = true;
      _ratingCount = newCount;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rating submitted successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 5,
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHospitalInfo(),
                    const SizedBox(height: 30),
                    _buildRatingSection(),
                    const SizedBox(height: 30),
                    _buildReviewInput(),
                    const SizedBox(height: 30),
                    _buildReviewsList(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('Hospital').doc(widget.hospitalId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SliverAppBar();
        final data = snapshot.data!.data() as Map<String, dynamic>;
        return SliverAppBar(
          expandedHeight: 250.0,
          floating: false,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(data['Hospital Name'], style: const TextStyle(fontSize: 18)),
            ),
            background: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: data['Background Image'],
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.grey[300]),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHospitalInfo() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('Hospital').doc(widget.hospitalId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final data = snapshot.data!.data() as Map<String, dynamic>;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'hospital_logo_${widget.hospitalId}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: data['Logo'],
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['Hospital Name'],
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 5),
                        Text(
                          '${data['City']}, ${data['Region']}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.phone, size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 5),
                        Text(
                          data['Contact'],
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildRatingSection() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rate this Hospital',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 8,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
                  ),
                  child: Slider(
                    value: _hospitalRating,
                    min: 0,
                    max: 5,
                    divisions: 10,
                    activeColor: Colors.teal,
                    inactiveColor: Colors.grey[300],
                    label: _hospitalRating.toStringAsFixed(1),
                    onChanged: _hasRated
                        ? null // Disable slider if user has rated
                        : (value) {
                      setState(() {
                        _hospitalRating = value;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.teal,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_hospitalRating.toStringAsFixed(1)}/5',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_averageRating.toStringAsFixed(1)} ★ ($_ratingCount ratings)',
                style: const TextStyle(fontSize: 16),
              ),
              if (!_hasRated)
                ElevatedButton(
                  onPressed: () => _submitRating(_hospitalRating),
                  child: const Text('Submit'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Write a Review', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
          controller: _reviewController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Share your experience...',
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _submitReview,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: Colors.teal,
            elevation: 2,
          ),
          child: const Text(
            'Submit Review',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('Hospital')
          .doc(widget.hospitalId)
          .collection('Reviews')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reviews', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            snapshot.data!.docs.isEmpty
                ? Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text(
                  'No reviews yet',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final review = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                return _buildReviewCard(review, snapshot.data!.docs[index].id);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review, String reviewId) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('Users').doc(review['userId']).get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return const SizedBox();
        final userData = userSnapshot.data!.data() as Map<String, dynamic>;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 5,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: NetworkImage(userData['User Pic']),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${userData['Fname']} ${userData['Lname']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          _formatTimestamp(review['timestamp']),
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(review['content'], style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      (review['likes'] as List?)?.contains(_currentUserId) ?? false
                          ? Icons.thumb_up
                          : Icons.thumb_up_outlined,
                      color: Colors.blue,
                    ),
                    onPressed: () => _toggleLike(reviewId, review['likes']),
                  ),
                  Text(
                    '${(review['likes'] as List?)?.length ?? 0}',
                    style: const TextStyle(color: Colors.blue),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: () => _showReplyDialog(context, reviewId),
                    child: const Text(
                      'Reply',
                      style: TextStyle(color: Colors.teal),
                    ),
                  ),
                ],
              ),
              _buildReplies(reviewId),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReplies(String reviewId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('Hospital')
          .doc(widget.hospitalId)
          .collection('Reviews')
          .doc(reviewId)
          .collection('Replies')
          .orderBy('timestamp')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        return Column(
          children: snapshot.data!.docs.map((replyDoc) {
            final reply = replyDoc.data() as Map<String, dynamic>;
            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('Users').doc(reply['userId']).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) return const SizedBox();
                final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(left: 40.0, top: 12.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundImage: NetworkImage(userData['User Pic']),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${userData['Fname']} ${userData['Lname']}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                reply['content'],
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTimestamp(reply['timestamp']),
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _submitReview() async {
    if (_reviewController.text.isEmpty || _currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a review and be logged in')),
      );
      return;
    }

    try {
      await _firestore
          .collection('Hospital')
          .doc(widget.hospitalId)
          .collection('Reviews')
          .add({
        'userId': _currentUserId,
        'content': _reviewController.text,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': [],
        'rating': _hospitalRating,
      });

      _reviewController.clear();
      setState(() => _hospitalRating = 0.0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting review: $e')),
      );
    }
  }

  Future<void> _toggleLike(String reviewId, List<dynamic>? currentLikes) async {
    if (_currentUserId == null) return;

    final reviewRef = _firestore
        .collection('Hospital')
        .doc(widget.hospitalId)
        .collection('Reviews')
        .doc(reviewId);

    try {
      if (currentLikes?.contains(_currentUserId) ?? false) {
        await reviewRef.update({
          'likes': FieldValue.arrayRemove([_currentUserId])
        });
      } else {
        await reviewRef.update({
          'likes': FieldValue.arrayUnion([_currentUserId])
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating like: $e')),
      );
    }
  }

  void _showReplyDialog(BuildContext context, String reviewId) {
    final replyController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Reply to Review',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: replyController,
                decoration: InputDecoration(
                  hintText: 'Write your reply...',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () async {
                      if (replyController.text.isNotEmpty && _currentUserId != null) {
                        try {
                          await _firestore
                              .collection('Hospital')
                              .doc(widget.hospitalId)
                              .collection('Reviews')
                              .doc(reviewId)
                              .collection('Replies')
                              .add({
                            'userId': _currentUserId,
                            'content': replyController.text,
                            'timestamp': FieldValue.serverTimestamp(),
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Reply submitted successfully')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error submitting reply: $e')),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Submit'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    final diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inDays > 0) return '${diff.inDays} days ago';
    if (diff.inHours > 0) return '${diff.inHours} hours ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes} minutes ago';
    return 'Just now';
  }
}