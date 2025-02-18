import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../Home/Widgets/organization_list_view.dart';
import 'Referral screens/ReferralSummaryScreen.dart';

class ReferralForm extends StatefulWidget {
  @override
  _ReferralFormState createState() => _ReferralFormState();
}

class _ReferralFormState extends State<ReferralForm> {
  final PageController _pageController = PageController();
  final _formKey = GlobalKey<FormState>();

  // Controllers for Patient Information
  final TextEditingController _patientRegController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  String? _selectedSex;
  DateTime? _dateOfBirth;
  int? _age;
  late String _serialNumber;
  String? selectedHospitalName;

  // Controllers for Referee Notes
  final TextEditingController _examinationFindingsController =
  TextEditingController();
  final TextEditingController _treatmentAdministeredController =
  TextEditingController();
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _reasonForReferralController =
  TextEditingController();

  // Health Facility selection
  String? _selectedHealthFacility;

  // Medical records upload (optional)
  String? _uploadedFileName;
  File? _uploadedFile;


  @override
  void initState() {
    super.initState();
    _serialNumber = _generateSerialNumber(7);
  }

  // Generates a random alphanumeric serial number of given length.
  String _generateSerialNumber(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  // Date picker that calculates age automatically.
  Future<void> _selectDate(BuildContext context) async {
    final DateTime initialDate = _dateOfBirth ?? DateTime(2000);
    final DateTime firstDate = DateTime(1900);
    final DateTime lastDate = DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null && picked != _dateOfBirth) {
      setState(() {
        _dateOfBirth = picked;
        _age = _calculateAge(picked);
      });
    }
  }

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  void _nextPage() {
    // Validate only required fields on page 1.
    print("Selected Health Facility: $selectedHospitalName");
    if (_formKey.currentState!.validate()) {
      _pageController.nextPage(
          duration: Duration(milliseconds: 300), curve: Curves.easeIn);
    }
  }

  void _previousPage() {
    _pageController.previousPage(
        duration: Duration(milliseconds: 300), curve: Curves.easeOut);
  }




  // Updated: Shows a bottom sheet with OrganizationListView.
  void _selectHealthFacility() async {
    // Open the bottom sheet and wait for the result (hospital name).
    final String? selectedHospitalName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: EdgeInsets.all(16),
          child: OrganizationListView(showSearchBar: true, isReferral: true),
        );
      },
    );

    // If a hospital name was selected, update the selected health facility state.
    if (selectedHospitalName != null) {
      setState(() {
        _selectedHealthFacility = selectedHospitalName; // Update with selected name
      });
    } else {
      setState(() {
        _selectedHealthFacility = null; // Reset the health facility value if no selection
      });
    }
  }

  void _uploadMedicalRecords() async {
    // Open the file picker dialog
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: false,  // You can set this to true if you want to allow multiple file selections.
      type: FileType.custom,  // Allow custom file types (you can specify file extensions if needed)
      allowedExtensions: ['pdf', 'jpg', 'png'], // Customize allowed file types (e.g. pdf, image files)
    );

    if (result != null) {
      // Get the selected file
      PlatformFile file = result.files.single;

      // Store the file as a File object for future use
      setState(() {
        _uploadedFile = File(file.path!); // Ensure the file path is not null
        _uploadedFileName = file.name;
      });

      // Show snack bar to notify user about file selection
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Medical records uploaded: ${file.name}")),
      );
    } else {
      // User canceled the file picking
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("File picking was canceled.")),
      );
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      if (_selectedHealthFacility == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please select a health facility")),
        );
        return; // Exit the method if no hospital is selected
      }

      // Pass the file to the ReferralSummaryScreen if uploaded
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReferralSummaryScreen(
            serialNumber: _serialNumber,
            patientRegNo: _patientRegController.text.isNotEmpty ? _patientRegController.text : null,
            patientName: _nameController.text,
            sex: _selectedSex,
            dateOfBirth: _dateOfBirth != null ? DateFormat('yyyy-MM-dd').format(_dateOfBirth!) : "Not provided",
            age: _age,
            examinationFindings: _examinationFindingsController.text,
            treatmentAdministered: _treatmentAdministeredController.text,
            diagnosis: _diagnosisController.text.isNotEmpty ? _diagnosisController.text : null,
            reasonForReferral: _reasonForReferralController.text,
            uploadedFileName: _uploadedFileName,
            selectedHospitalName: _selectedHealthFacility,
            uploadedFile: _uploadedFile,
            showConfirm: true,// Pass the actual file here
          ),
        ),
      );
    }
  }




  @override
  void dispose() {
    _patientRegController.dispose();
    _nameController.dispose();
    _examinationFindingsController.dispose();
    _treatmentAdministeredController.dispose();
    _diagnosisController.dispose();
    _reasonForReferralController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A consistent padding for better UI.
    const contentPadding = EdgeInsets.all(16.0);

    return Scaffold(
      appBar: AppBar(
        title: Text("Referral Form"),
      ),
      body: Form(
        key: _formKey,
        child: PageView(
          controller: _pageController,
          physics: NeverScrollableScrollPhysics(), // Prevent manual swiping.
          children: [

            // ----- Page 1: Patient Information -----
            SingleChildScrollView(
              padding: contentPadding,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: EdgeInsets.all(8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Patient Information",
                          style: Theme.of(context).textTheme.titleLarge),
                      SizedBox(height: 16),
                      // Row: Patient Reg. No. (Optional) and Serial Number
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _patientRegController,
                              decoration: InputDecoration(
                                labelText: "Patient Reg. No. (Optional)",
                                border: OutlineInputBorder(),
                              ),
                              // Optional field: No validator provided.
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "Serial: $_serialNumber",
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      // Name Field (Required)
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: "Name",
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Enter the patient's name";
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      // Sex Radio Buttons (Required)
                      Text("Sex", style: TextStyle(fontSize: 16)),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: Text("M"),
                              value: "Male",
                              groupValue: _selectedSex,
                              onChanged: (val) {
                                setState(() {
                                  _selectedSex = val;
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: Text("F"),
                              value: "Female",
                              groupValue: _selectedSex,
                              onChanged: (val) {
                                setState(() {
                                  _selectedSex = val;
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: Text("Other"),
                              value: "Other",
                              groupValue: _selectedSex,
                              onChanged: (val) {
                                setState(() {
                                  _selectedSex = val;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      // Row: Date of Birth and Age (Required)
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: GestureDetector(
                              onTap: () => _selectDate(context),
                              child: AbsorbPointer(
                                child: TextFormField(
                                  decoration: InputDecoration(
                                    labelText: "Date of Birth",
                                    border: OutlineInputBorder(),
                                    suffixIcon: Icon(Icons.calendar_today),
                                  ),
                                  controller: TextEditingController(
                                    text: _dateOfBirth != null
                                        ? DateFormat('yyyy-MM-dd')
                                        .format(_dateOfBirth!)
                                        : "",
                                  ),
                                  validator: (value) {
                                    if (_dateOfBirth == null) {
                                      return "Select date of birth";
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _age != null ? "Age: $_age" : "Age",
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24),
                      // Next button to proceed to Referee Notes page
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [

                          ElevatedButton(
                            onPressed: _nextPage,
                            child: Text("Next"),
                          )
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
            // ----- Page 2: Referee Notes & Additional Features -----
            SingleChildScrollView(
              padding: contentPadding,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: EdgeInsets.all(8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Referee Notes",
                          style: Theme.of(context).textTheme.titleLarge),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _examinationFindingsController,
                        decoration: InputDecoration(
                          labelText: "Examination Findings",
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Enter examination findings";
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _treatmentAdministeredController,
                        decoration: InputDecoration(
                          labelText: "Treatment Administered",
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Enter treatment administered";
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      // Diagnosis is optional.
                      TextFormField(
                        controller: _diagnosisController,
                        decoration: InputDecoration(
                          labelText: "Diagnosis (Optional)",
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _reasonForReferralController,
                        decoration: InputDecoration(
                          labelText: "Reason for Referral",
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Enter reason for referral";
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 24),
                      // Upload Medical Records (Optional)
                      Text("Upload Medical Records (Optional)",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _uploadMedicalRecords,
                        icon: Icon(Icons.upload_file),
                        label: Text(_uploadedFileName == null
                            ? "Upload File"
                            : "Uploaded: $_uploadedFileName"),
                      ),
                      SizedBox(height: 24),
                      // Health Facility selection button.


                      SizedBox(height: 24),
                      // Navigation: Back and Submit buttons.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton(
                            onPressed: _previousPage,
                            child: Text("Back"),
                          ),
                          ElevatedButton(
                            onPressed: _nextPage,
                            child: Text("Next"),
                          )
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text("Select Health Facility", style: Theme.of(context).textTheme.titleLarge),
                  SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _selectHealthFacility,
                    icon: Icon(Icons.local_hospital),
                    label: Text(
                      _selectedHealthFacility == null
                          ? "Select Health Facility (Required)"
                          : "Selected: $_selectedHealthFacility",
                    ),
                  ),
                  SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(onPressed: _previousPage, child: Text("Back")),
                      ElevatedButton(onPressed: _submitForm, child: Text("Submit")),
                    ],
                  ),
                ],
              ),
            ),


          ],
        ),
      ),
    );
  }
}

