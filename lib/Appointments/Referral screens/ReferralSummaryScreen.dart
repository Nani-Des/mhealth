import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:nhap/Home/home_page.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class ReferralSummaryScreen extends StatefulWidget {
  final String serialNumber;
  final String? patientRegNo;
  final String patientName;
  final String? sex;
  final String dateOfBirth;
  final int? age;
  final String examinationFindings;
  final String treatmentAdministered;
  final String? diagnosis;
  final String reasonForReferral;
  final String? uploadedFileName;
  final String? selectedHospitalName;
  final File? uploadedFile;
  final bool showConfirm;

  ReferralSummaryScreen({
    required this.serialNumber,
    required this.patientRegNo,
    required this.patientName,
    required this.sex,
    required this.dateOfBirth,
    required this.age,
    required this.examinationFindings,
    required this.treatmentAdministered,
    required this.diagnosis,
    required this.reasonForReferral,
    required this.uploadedFileName,
    required this.selectedHospitalName,
    this.uploadedFile,
    required this.showConfirm,
  });

  @override
  _ReferralSummaryScreenState createState() => _ReferralSummaryScreenState();
}

class _ReferralSummaryScreenState extends State<ReferralSummaryScreen> {
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _uploadResultMessage;

  Future<void> saveReferralToFirestore(BuildContext context) async {
    if (widget.selectedHospitalName == null || widget.selectedHospitalName!.isEmpty) {
      _showMessage(context, "Error", "Selected hospital is required", isError: true);
      return;
    }
    String? userId = FirebaseAuth.instance.currentUser?.uid;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadResultMessage = null;
    });

    try {
      String? fileUrl;
      if (widget.uploadedFile != null) {
        fileUrl = await _uploadFile();
      }

      QuerySnapshot hospitalQuery = await FirebaseFirestore.instance
          .collection('Hospital')
          .where('Hospital Name', isEqualTo: widget.selectedHospitalName)
          .get();

      if (hospitalQuery.docs.isEmpty) {
        setState(() {
          _isUploading = false;
          _uploadResultMessage = "Hospital not found";
        });
        _showMessage(context, "Error", "Hospital not found", isError: true);
        return;
      }

      String hospitalId = hospitalQuery.docs.first.id;
      await FirebaseFirestore.instance
          .collection('Hospital')
          .doc(hospitalId)
          .collection('Referrals')
          .doc(widget.serialNumber)
          .set({
        'Serial Number': widget.serialNumber,
        'Patient Reg. No.': widget.patientRegNo ?? "N/A",
        'Name': widget.patientName,
        'Sex': widget.sex ?? "N/A",
        'Date of Birth': widget.dateOfBirth,
        'Age': widget.age?.toString() ?? "N/A",
        'Examination Findings': widget.examinationFindings,
        'Treatment Administered': widget.treatmentAdministered,
        'Diagnosis': widget.diagnosis ?? "N/A",
        'Reason for Referral': widget.reasonForReferral,
        'Uploaded Medical Records': fileUrl ?? "No file uploaded",
        'Selected Health Facility': widget.selectedHospitalName,
        'Timestamp': FieldValue.serverTimestamp(),
        'Referred By': userId,
      });

      setState(() {
        _isUploading = false;
        _uploadResultMessage = "Referral sent successfully";
      });

      // Navigate to HomePage immediately and show SnackBar
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text("Referral sent successfully")),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Print',
            textColor: Colors.white,
            onPressed: () async {
              final pdf = await _generateReferralReceipt();
              await Printing.layoutPdf(
                onLayout: (PdfPageFormat format) async => pdf.save(),
              );
            },
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadResultMessage = "Failed to send referral. Check internet connectivity!";
      });
      _showMessage(context, "Error", "Check internet connectivity!", isError: true);
    }
  }

  Future<String?> _uploadFile() async {
    try {
      if (widget.uploadedFile == null) return null;
      Reference storageRef = FirebaseStorage.instance.ref().child('referral_files/${widget.serialNumber}');
      UploadTask uploadTask = storageRef.putFile(widget.uploadedFile!);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          _uploadProgress = (snapshot.bytesTransferred / snapshot.totalBytes).clamp(0.0, 1.0);
        });
      });

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      setState(() {
        _uploadResultMessage = "Failed to upload file.";
      });
      return null;
    }
  }

  Future<pw.Document> _generateReferralReceipt() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        margin: pw.EdgeInsets.all(40),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Container(
              alignment: pw.Alignment.center,
              padding: pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.teal, width: 2)),
              ),
              child: pw.Text(
                "Referral Receipt",
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal,
                ),
              ),
            ),
            pw.SizedBox(height: 20),

            // Patient Information Section
            pw.Text(
              "Patient Information",
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            ),
            pw.Divider(),
            pw.SizedBox(height: 10),
            _buildPdfRow("Serial Number", widget.serialNumber),
            _buildPdfRow("Patient Reg. No.", widget.patientRegNo ?? "N/A"),
            _buildPdfRow("Name", widget.patientName),
            _buildPdfRow("Sex", widget.sex ?? "N/A"),
            _buildPdfRow("Date of Birth", widget.dateOfBirth),
            _buildPdfRow("Age", widget.age?.toString() ?? "N/A"),
            pw.SizedBox(height: 20),

            // Referee Notes Section
            pw.Text(
              "Referee Notes",
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            ),
            pw.Divider(),
            pw.SizedBox(height: 10),
            _buildPdfRow("Examination Findings", widget.examinationFindings),
            _buildPdfRow("Treatment Administered", widget.treatmentAdministered),
            _buildPdfRow("Diagnosis", widget.diagnosis ?? "N/A"),
            _buildPdfRow("Reason for Referral", widget.reasonForReferral),
            pw.SizedBox(height: 20),

            // Additional Information Section
            pw.Text(
              "Additional Information",
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            ),
            pw.Divider(),
            pw.SizedBox(height: 10),
            _buildPdfRow("Uploaded Attachments", widget.uploadedFileName ?? "No file uploaded"),
            _buildPdfRow("Selected Health Facility", widget.selectedHospitalName ?? "Not selected"),
            pw.SizedBox(height: 20),

            // Footer
            pw.Spacer(),
            pw.Divider(),
            pw.Text(
              "Generated on: ${DateTime.now().toString().split('.')[0]}",
              style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic, color: PdfColors.grey),
            ),
          ],
        ),
      ),
    );

    return pdf;
  }

  pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "$label: ",
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareReferralReceipt() async {
    final pdf = await _generateReferralReceipt();
    final pdfBytes = await pdf.save();

    // Save temporarily to share
    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/referral_${widget.serialNumber}.pdf';
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);

    // Share the file
    await Share.shareXFiles(
      [XFile(filePath, mimeType: 'application/pdf')],
      subject: 'Referral Receipt - ${widget.serialNumber}',
      text: 'Here is the referral receipt for ${widget.patientName}.',
    );
  }

  void _showMessage(BuildContext context, String title, String message, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? Colors.red : Colors.green,
            ),
            SizedBox(width: 8),
            Text(title, style: TextStyle(color: isError ? Colors.red : Colors.green)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomePage()),
              );
            },
            child: Text("Okay", style: TextStyle(color: Colors.teal)),
          ),
        ],
      ),
    );
  }

  void _showMessageWithPrintOption(BuildContext context, String title, String message, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? Colors.red : Colors.green,
            ),
            SizedBox(width: 8),
            Text(title, style: TextStyle(color: isError ? Colors.red : Colors.green)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final pdf = await _generateReferralReceipt();
              await Printing.layoutPdf(
                onLayout: (PdfPageFormat format) async => pdf.save(),
              );
            },
            child: Text("Print Receipt", style: TextStyle(color: Colors.teal)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomePage()),
              );
            },
            child: Text("Okay", style: TextStyle(color: Colors.teal)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Referral Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white)),
        backgroundColor: Colors.teal,
        elevation: 0,
        actions: [
          if (widget.showConfirm)
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: ElevatedButton(
                onPressed: _isUploading ? null : () => saveReferralToFirestore(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, size: 20),
                    SizedBox(width: 8),
                    Text("Confirm", style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          if (!widget.showConfirm)
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: IconButton(
                icon: Icon(Icons.share, color: Colors.white),
                tooltip: 'Share Referral PDF',
                onPressed: () async {
                  try {
                    await _shareReferralReceipt();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Failed to share PDF: $e"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            color: Colors.grey[100],
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionCard(
                    context,
                    "Patient Information",
                    [
                      _buildInfoRow("Serial Number", widget.serialNumber),
                      _buildInfoRow("Patient Reg. No.", widget.patientRegNo ?? "N/A"),
                      _buildInfoRow("Name", widget.patientName),
                      _buildInfoRow("Sex", widget.sex ?? "N/A"),
                      _buildInfoRow("Date of Birth", widget.dateOfBirth),
                      _buildInfoRow("Age", widget.age?.toString() ?? "N/A"),
                    ],
                  ),
                  SizedBox(height: 16),
                  _buildSectionCard(
                    context,
                    "Referee Notes",
                    [
                      _buildInfoRow("Examination Findings", widget.examinationFindings),
                      _buildInfoRow("Treatment Administered", widget.treatmentAdministered),
                      _buildInfoRow("Diagnosis", widget.diagnosis ?? "N/A"),
                      _buildInfoRow("Reason for Referral", widget.reasonForReferral),
                    ],
                  ),
                  SizedBox(height: 16),
                  _buildSectionCard(
                    context,
                    "Additional Information",
                    [
                      _buildInfoRow("Uploaded Attachments", widget.uploadedFileName ?? "No file uploaded"),
                      _buildInfoRow("Selected Health Facility", widget.selectedHospitalName ?? "Not selected"),
                    ],
                  ),
                  if (_uploadResultMessage != null) ...[
                    SizedBox(height: 16),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              _uploadResultMessage!.contains("success") ? Icons.check_circle : Icons.error,
                              color: _uploadResultMessage!.contains("success") ? Colors.green : Colors.red,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _uploadResultMessage!,
                                style: TextStyle(
                                  color: _uploadResultMessage!.contains("success") ? Colors.green : Colors.red,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: 32),
                ],
              ),
            ),
          ),
          if (_isUploading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      value: _uploadProgress,
                      backgroundColor: Colors.grey[300],
                      color: Colors.teal,
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Uploading... ${(_uploadProgress * 100).toStringAsFixed(0)}%",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, String title, List<Widget> children) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.teal,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              "$label:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[800]),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}