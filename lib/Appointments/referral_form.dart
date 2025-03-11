import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Home/Widgets/organization_list_view.dart';
import 'Referral screens/ReferralSummaryScreen.dart';

class ReferralForm extends StatefulWidget {
  final String? selectedHealthFacility; // Optional parameter for pre-selected health facility

  const ReferralForm({Key? key, this.selectedHealthFacility}) : super(key: key);

  @override
  _ReferralFormState createState() => _ReferralFormState();
}

class _ReferralFormState extends State<ReferralForm> {
  final PageController _pageController = PageController();
  final _formKey = GlobalKey<FormState>();

  // Controllers and variables
  final TextEditingController _patientRegController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _examinationFindingsController = TextEditingController();
  final TextEditingController _treatmentAdministeredController = TextEditingController();
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _reasonForReferralController = TextEditingController();

  String? _selectedSex;
  DateTime? _dateOfBirth;
  int? _age;
  late String _serialNumber;
  String? _selectedHealthFacility; // This will now be initialized with widget.selectedHealthFacility
  String? _uploadedFileName;
  File? _uploadedFile;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _serialNumber = _generateSerialNumber(7);
    _selectedHealthFacility = widget.selectedHealthFacility; // Initialize with passed value or null
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page?.round() ?? 0;
      });
    });
  }

  String _generateSerialNumber(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: Colors.teal),
            buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
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
    if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  void _nextPage() {
    if (_formKey.currentState!.validate()) {
      _pageController.nextPage(duration: Duration(milliseconds: 300), curve: Curves.easeIn);
    }
  }

  void _previousPage() {
    _pageController.previousPage(duration: Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _selectHealthFacility() async {
    final String? result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: EdgeInsets.all(16),
        child: OrganizationListView(showSearchBar: true, isReferral: true),
      ),
    );
    if (result != null) {
      setState(() => _selectedHealthFacility = result);
    }
  }

  void _uploadMedicalRecords() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png'],
    );
    if (result != null) {
      PlatformFile file = result.files.single;
      setState(() {
        _uploadedFile = File(file.path!);
        _uploadedFileName = file.name;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Uploaded: ${file.name}", style: TextStyle(color: Colors.white))),
      );
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate() && _selectedHealthFacility != null) {
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
            showConfirm: true,
          ),
        ),
      );
    } else if (_selectedHealthFacility == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select a health facility")),
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
    return Scaffold(
      appBar: AppBar(
        title: Text("Referral Form", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.grey[100],
        child: Column(
          children: [
            // Progress Indicator
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) => _buildStepIndicator(index)),
              ),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: PageView(
                  controller: _pageController,
                  physics: NeverScrollableScrollPhysics(),
                  children: [
                    _buildPatientInfoPage(),
                    _buildRefereeNotesPage(),
                    _buildHealthFacilityPage(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int index) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: CircleAvatar(
        radius: 12,
        backgroundColor: _currentPage >= index ? Colors.teal : Colors.grey[400],
        child: Text(
          "${index + 1}",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildPatientInfoPage() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Patient Information",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.teal)),
              SizedBox(height: 24),
              // Row with Patient Reg No and Serial Number
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTextField(_patientRegController, "Patient Reg. No. (Optional)",
                        isRequired: false),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "Serial: $_serialNumber",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              _buildTextField(_nameController, "Name"),
              SizedBox(height: 24),
              Text("Sex", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              _buildSexSelection(),
              SizedBox(height: 24),
              _buildDateOfBirthField(),
              SizedBox(height: 32),
              _buildNavigationButtons(nextOnly: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRefereeNotesPage() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Referee Notes",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.teal)),
              SizedBox(height: 24),
              _buildTextField(_examinationFindingsController, "Examination Findings", maxLines: 3),
              SizedBox(height: 16),
              _buildTextField(_treatmentAdministeredController, "Treatment Administered", maxLines: 3),
              SizedBox(height: 16),
              _buildTextField(_diagnosisController, "Diagnosis (Optional)", maxLines: 2, isRequired: false),
              SizedBox(height: 16),
              _buildTextField(_reasonForReferralController, "Reason for Referral", maxLines: 3),
              SizedBox(height: 24),
              _buildUploadButton(),
              SizedBox(height: 32),
              _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthFacilityPage() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Select Health Facility",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.teal)),
              SizedBox(height: 32),
              _buildHealthFacilityButton(),
              SizedBox(height: 48),
              _buildNavigationButtons(isLastPage: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {int maxLines = 1, bool isRequired = true}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
      validator: isRequired ? (value) => value!.isEmpty ? "Please enter $label" : null : null,
    );
  }

  Widget _buildSexSelection() {
    return Row(
      children: ["Male", "Female", "Other"].map((sex) => Expanded(
        child: RadioListTile<String>(
          title: Text(sex[0], style: TextStyle(fontWeight: FontWeight.bold)),
          value: sex,
          groupValue: _selectedSex,
          onChanged: (val) => setState(() => _selectedSex = val),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      )).toList(),
    );
  }

  Widget _buildDateOfBirthField() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: () => _selectDate(context),
            child: AbsorbPointer(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: "Date of Birth",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: Icon(Icons.calendar_today, color: Colors.teal),
                  filled: true,
                  fillColor: Colors.white,
                ),
                controller: TextEditingController(
                  text: _dateOfBirth != null ? DateFormat('yyyy-MM-dd').format(_dateOfBirth!) : "",
                ),
                validator: (value) => _dateOfBirth == null ? "Select date of birth" : null,
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
              color: Colors.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _age != null ? "Age: $_age" : "Age",
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadButton() {
    return OutlinedButton.icon(
      onPressed: _uploadMedicalRecords,
      icon: Icon(Icons.upload_file, color: Colors.teal),
      label: Text(
        _uploadedFileName == null ? "Upload Medical Records" : "Uploaded: $_uploadedFileName",
        style: TextStyle(color: Colors.teal),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.teal),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    );
  }

  Widget _buildHealthFacilityButton() {
    return ElevatedButton.icon(
      onPressed: _selectHealthFacility,
      icon: Icon(Icons.local_hospital),
      label: Text(
        _selectedHealthFacility == null
            ? "Select Health Facility"
            : "Selected: $_selectedHealthFacility",
        overflow: TextOverflow.ellipsis,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        minimumSize: Size(double.infinity, 50),
      ),
    );
  }

  Widget _buildNavigationButtons({bool nextOnly = false, bool isLastPage = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (!nextOnly) ...[
          TextButton(
            onPressed: _previousPage,
            child: Row(
              children: [
                Icon(Icons.arrow_back, color: Colors.teal),
                SizedBox(width: 8),
                Text("Back", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ] else
          Spacer(),
        ElevatedButton(
          onPressed: isLastPage ? _submitForm : _nextPage,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isLastPage ? "Submit" : "Next", style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(width: 8),
              Icon(isLastPage ? Icons.check : Icons.arrow_forward),
            ],
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          ),
        ),
      ],
    );
  }
}