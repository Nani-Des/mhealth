import 'package:flutter/material.dart';
import '../../Services/firebase_service.dart';
import '../shift_schedule_Table.dart';
import 'custom_nav_bar.dart';

class CalenderPage extends StatefulWidget {
  final String hospitalId;
  final bool isReferral;
  final Function? selectHealthFacility;

  const CalenderPage({
    Key? key,
    required this.hospitalId,
    required this.isReferral,
    this.selectHealthFacility,
  }) : super(key: key);

  @override
  State<CalenderPage> createState() => _CalenderPageState();
}

class _CalenderPageState extends State<CalenderPage> with TickerProviderStateMixin {
  Map<String, String> _hospitalDetails = {};
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _doctors = [];
  String? _selectedDepartmentId;
  bool _isLoading = true;
  bool _isDoctorsLoading = false;
  FirebaseService _firebaseService = FirebaseService();

  late AnimationController _textAnimationController;
  late Animation<double> _textFadeAnimation;
  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _loadHospitalData();

    _textAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _textFadeAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _textAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _progressAnimationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    )..repeat();
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(_progressAnimationController);
  }

  Future<void> _loadHospitalData() async {
    try {
      Map<String, String> hospitalDetails = await _firebaseService.getHospitalDetails(widget.hospitalId);
      List<Map<String, dynamic>> departments =
      await _firebaseService.getDepartmentsForHospital(widget.hospitalId);

      if (departments.isNotEmpty) {
        _selectedDepartmentId = departments.first['Department ID'];
        _loadDoctorsForDepartment(_selectedDepartmentId!);
      }

      setState(() {
        _hospitalDetails = hospitalDetails;
        _departments = departments;
        _isLoading = false;
      });
    } catch (error) {
      print('Error fetching hospital data: $error');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDoctorsForDepartment(String departmentId) async {
    setState(() {
      _isDoctorsLoading = true;
      _selectedDepartmentId = departmentId;
    });
    try {
      List<Map<String, dynamic>> doctors =
      await _firebaseService.getDoctorsForDepartment(widget.hospitalId, departmentId);
      setState(() {
        _doctors = doctors;
        _isDoctorsLoading = false;
      });
    } catch (error) {
      print('Error fetching doctors: $error');
      setState(() {
        _isDoctorsLoading = false;
      });
    }
  }

  String _getDepartmentIcon(String departmentName) {
    String normalizedDept = departmentName.toLowerCase();

    if (normalizedDept.contains('emergency') || normalizedDept.contains('trauma')) {
      return '🚑';
    } else if (normalizedDept.contains('cardiology') || normalizedDept.contains('heart')) {
      return '🫀';
    } else if (normalizedDept.contains('neurology') || normalizedDept.contains('brain')) {
      return '🧠';
    } else if (normalizedDept.contains('oncology') || normalizedDept.contains('cancer')) {
      return '🎗️';
    } else if (normalizedDept.contains('surgery')) {
      return '🔪';
    } else if (normalizedDept.contains('orthopedic') || normalizedDept.contains('bone')) {
      return '🦴';
    } else if (normalizedDept.contains('ophthalmology') || normalizedDept.contains('eye')) {
      return '👁️';
    } else if (normalizedDept.contains('dentistry') || normalizedDept.contains('dental')) {
      return '🦷';
    } else if (normalizedDept.contains('pediatrics') || normalizedDept.contains('child')) {
      return '👶';
    } else if (normalizedDept.contains('maternity') || normalizedDept.contains('obstetrics')) {
      return '🤰';
    } else if (normalizedDept.contains('dermatology') || normalizedDept.contains('skin')) {
      return '🧴';
    } else if (normalizedDept.contains('psychiatry') || normalizedDept.contains('mental')) {
      return '🧠💭';
    } else if (normalizedDept.contains('rehabilitation') || normalizedDept.contains('therapy')) {
      return '🏃‍♂️';
    } else if (normalizedDept.contains('radiology') || normalizedDept.contains('imaging')) {
      return '🩻';
    } else if (normalizedDept.contains('nephrology') || normalizedDept.contains('kidney')) {
      return '🫁';
    } else {
      return '🏥';
    }
  }

  @override
  void dispose() {
    _textAnimationController.dispose();
    _progressAnimationController.dispose();
    super.dispose();
  }

  Widget _buildSophisticatedProgressIndicator() {
    return AnimatedBuilder(
      animation: _progressAnimationController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: _progressAnimation.value,
                strokeWidth: 8,
                backgroundColor: Colors.teal.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
              ),
            ),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.teal.shade100, Colors.teal.shade300],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.3),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${(_progressAnimation.value * 100).toInt()}%',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal,
        elevation: 0,
        title: Text(
          _hospitalDetails['hospitalName'] ?? 'Loading Hospital..',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSophisticatedProgressIndicator(),
            SizedBox(height: 16),
            Text(
              "Loading Hospital Data...",
              style: TextStyle(fontSize: 16, color: Colors.teal),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'View Department Roster',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.85,
                ),
                itemCount: _departments.length,
                itemBuilder: (context, index) {
                  final department = _departments[index];
                  final departmentId = department['Department ID'];
                  final departmentName = department['Department Name'] ?? 'Unnamed';
                  return DepartmentCard(
                    departmentName: departmentName,
                    departmentIcon: _getDepartmentIcon(departmentName),
                    onTap: () async {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildSophisticatedProgressIndicator(),
                              SizedBox(height: 16),
                              Text(
                                "Loading Doctors...",
                                style: TextStyle(fontSize: 16, color: Colors.teal),
                              ),
                            ],
                          ),
                        ),
                      );

                      await _loadDoctorsForDepartment(departmentId);
                      Navigator.pop(context);

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ShiftScheduleScreen(
                            hospitalId: widget.hospitalId,
                            doctors: _doctors,
                            isReferral: widget.isReferral,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: widget.isReferral
          ? Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FadeTransition(
            opacity: _textFadeAnimation,
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Text(
                "Tap Here To Add Hospital",
                style: TextStyle(
                  color: Colors.teal,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          FloatingActionButton(
            onPressed: () {
              String selectedHospitalName = _hospitalDetails['hospitalName'] ?? 'Loading Hospital..';

              Navigator.pop(context, selectedHospitalName);
              Navigator.pop(context, selectedHospitalName);
              Navigator.pop(context, selectedHospitalName);

              Future.delayed(Duration(milliseconds: 300), () {
                if (widget.selectHealthFacility != null) {
                  widget.selectHealthFacility!(selectedHospitalName);
                }
              });
            },
            child: Icon(Icons.add),
            backgroundColor: Colors.teal,
          ),
        ],
      )
          : null,
      bottomNavigationBar:
      widget.isReferral ? null : CustomBottomNavBarHospital(hospitalId: widget.hospitalId),
    );
  }
}

class DepartmentCard extends StatelessWidget {
  final String departmentName;
  final String departmentIcon;
  final VoidCallback onTap;

  const DepartmentCard({
    Key? key,
    required this.departmentName,
    required this.departmentIcon,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.grey[50]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                departmentIcon,
                style: const TextStyle(fontSize: 40),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  departmentName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}