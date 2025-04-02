import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Fetch hospital details (name and logo) for a specific hospital
  Future<Map<String, String>> getHospitalDetails(String hospitalId) async {
    DocumentSnapshot hospitalDoc = await _db.collection('Hospital').doc(hospitalId).get();
    String hospitalName = hospitalDoc.get('Hospital Name');
    String logo = hospitalDoc.get('Logo');
    return {'hospitalName': hospitalName, 'logo': logo};
  }

  // Fetch department names based on Hospital's Department IDs
  Future<List<Map<String, dynamic>>> getDepartmentsForHospital(String hospitalId) async {
    DocumentSnapshot hospitalDoc = await _db.collection('Hospital').doc(hospitalId).get();
    List<dynamic> departmentIds = hospitalDoc.get('Hospital Department');

    List<Map<String, dynamic>> departments = [];
    for (String departmentId in departmentIds) {
      DocumentSnapshot departmentDoc = await _db.collection('Department').doc(departmentId).get();
      String departmentName = departmentDoc.get('Department Name');
      departments.add({
        'Department ID': departmentId,
        'Department Name': departmentName,
      });
    }

    return departments;
  }

  // Fetch doctors based on hospital and department, including userId for doctor identification
  Future<List<Map<String, dynamic>>> getDoctorsForDepartment(String hospitalId, String departmentId) async {
    QuerySnapshot querySnapshot = await _db
        .collection('Users')
        .where('Hospital ID', isEqualTo: hospitalId)
        .where('Department ID', isEqualTo: departmentId)
        .where('Role', isEqualTo: true)  // Only fetch documents where 'Role' is true
        .get();

    List<Map<String, dynamic>> doctors = [];
    for (var doc in querySnapshot.docs) {
      String userId = doc.id; // Get the unique user ID from document ID
      String lname = doc.get('Lname');
      String experience = doc.get('Experience').toString();
      String userPic = doc.get('User Pic') ?? '';  // In case the field is null
      doctors.add({
        'userId': userId,        // Include userId in the doctor details
        'name': 'Dr. $lname',
        'experience': '$experience Yrs',
        'userPic': userPic,
      });
    }

    return doctors;
  }

  // Fetch details of a specific doctor based on userId
  Future<Map<String, dynamic>> getDoctorDetails(String userId) async {
    DocumentSnapshot userDoc = await _db
        .collection('Users')
        .doc(userId)
        .get();

    if (userDoc.get('Role') == true) {  // Check if 'Role' is true
      return {
        'Fname': userDoc.get('Fname'),  // First name
        'Lname': userDoc.get('Lname'),  // Last name
        'Region': userDoc.get('Region'), // Region
        'Title': userDoc.get('Title'),   // Title
        'Email': userDoc.get('Email'),   // Email
        'Mobile Number': userDoc.get('Mobile Number'), // Mobile Number
        'Experience': userDoc.get('Experience').toString(), // Experience as a string
        'userPic': userDoc.get('User Pic') ?? '',  // In case the field is null
        'departmentId': userDoc.get('Department ID'),
        'hospitalId': userDoc.get('Hospital ID'),
        'Status': userDoc.get('Status') ?? 'Available', // Status
      };
    } else {
      throw Exception('User role is not set to true');  // Handle case where Role is not true
    }
  }

  // Fetch department name based on department ID
  Future<String> getDepartmentName(String departmentId) async {
    DocumentSnapshot departmentDoc = await _db.collection('Department').doc(departmentId).get();
    return departmentDoc.get('Department Name') as String;
  }

  // Fetch hospital name based on hospital ID
  Future<String> getHospitalName(String hospitalId) async {
    DocumentSnapshot hospitalDoc = await _db.collection('Hospital').doc(hospitalId).get();
    return hospitalDoc.get('Hospital Name') as String;
  }
}
