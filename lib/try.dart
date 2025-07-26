import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddDesignationPage extends StatefulWidget {
  const AddDesignationPage({Key? key}) : super(key: key);

  @override
  _AddDesignationPageState createState() => _AddDesignationPageState();
}

class _AddDesignationPageState extends State<AddDesignationPage> {
  bool _isLoading = false;

  Future<void> _addDesignationToUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch all documents from the "Users" collection
      QuerySnapshot usersSnapshot =
      await FirebaseFirestore.instance.collection('Users').get();

      // Iterate through each document
      for (var doc in usersSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        // Check if the "Role" field exists and is set to true
        if (data.containsKey('Role') && data['Role'] == true) {
          // Update the document to add the "Designation" field
          await FirebaseFirestore.instance
              .collection('Users')
              .doc(doc.id)
              .update({
            'Designation': 'Doctor', // Set a default value, e.g., 'Doctor'
          });
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Designation field added to eligible users successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding Designation field: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Designation to Users',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
        )
            : ElevatedButton(
          onPressed: _addDesignationToUsers,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Add Designation Field',
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}