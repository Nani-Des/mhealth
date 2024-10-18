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

  // Fetch department names for a specific hospital
  Future<List<String>> getDepartmentsForHospital(String hospitalId) async {
    DocumentSnapshot hospitalDoc = await _db.collection('Hospital').doc(hospitalId).get();
    List<dynamic> departmentIds = hospitalDoc.get('Hospital Department');

    List<String> departmentNames = [];
    for (String departmentId in departmentIds) {
      DocumentSnapshot departmentDoc = await _db.collection('Department').doc(departmentId).get();
      String departmentName = departmentDoc.get('Department Name');
      departmentNames.add(departmentName);
    }

    return departmentNames;
  }

  // Fetch doctors based on hospital and department
  Future<List<Map<String, dynamic>>> getDoctorsForDepartment(String hospitalId, String departmentId) async {
    QuerySnapshot querySnapshot = await _db
        .collection('Users')
        .where('Hospital ID', isEqualTo: hospitalId)
        .where('Department ID', isEqualTo: departmentId)
        .get();

    List<Map<String, dynamic>> doctors = [];
    for (var doc in querySnapshot.docs) {
      String lname = doc.get('Lname');
      String experience = doc.get('Experience').toString();
      String userPic = doc.get('User Pic');
      doctors.add({
        'name': 'Dr. $lname',
        'experience': '$experience Yrs',
        'userPic': userPic,
      });
    }

    return doctors;
  }
}
