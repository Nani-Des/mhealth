import 'package:flutter/material.dart';
import 'package:mhealth/Hospital/Widgets/custom_nav_bar.dart';
import 'package:mhealth/Hospital/specialty_details.dart';
import '../Services/firebase_service.dart';
import '../try.dart';
import 'Widgets/calender_page.dart';
import 'hospital_service_screen.dart';

class HospitalPage extends StatefulWidget {
  final String hospitalId;
  final bool isReferral;
  final Function? selectHealthFacility;

  const HospitalPage({
    super.key,
    required this.hospitalId,
    required this.isReferral,
    this.selectHealthFacility,
  });

  @override
  _HospitalPageState createState() => _HospitalPageState();
}

class _HospitalPageState extends State<HospitalPage> {
  final FirebaseService _firebaseService = FirebaseService();
  Map<String, String> _hospitalDetails = {'hospitalName': '', 'logo': ''};

  @override
  void initState() {
    super.initState();
    _loadHospitalData();
  }

  Future<void> _loadHospitalData() async {
    try {
      Map<String, String> hospitalDetails =
      await _firebaseService.getHospitalDetails(widget.hospitalId);
      setState(() {
        _hospitalDetails = hospitalDetails;
      });
    } catch (error) {
      print('Error fetching hospital data: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _hospitalDetails['hospitalName'] ?? 'Loading Hospital..',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal[100]!, Colors.teal[50]!, Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
          child: Column(
            children: [
              const Text(
                'Welcome',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CardButton(
                      title: 'Physicians',
                      icon: Icons.person,
                      gradient: LinearGradient(
                        colors: [Colors.blue[700]!, Colors.blue[500]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SpecialtyDetails(
                              hospitalId: widget.hospitalId,
                              isReferral: widget.isReferral,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Flexible(
                          child: CardButton(
                            title: 'Hospital Services',
                            icon: Icons.medical_services,
                            gradient: LinearGradient(
                              colors: [Colors.teal[700]!, Colors.teal[500]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      HospitalServiceScreen(hospitalId: widget.hospitalId,isReferral: widget.isReferral)
                              ));
                            },
                          ),
                        ),
                        const SizedBox(width: 20),
                        Flexible(
                          child: CardButton(
                            title: 'Hospital Calendar',
                            icon: Icons.calendar_today,
                            gradient: LinearGradient(
                              colors: [Colors.purple[700]!, Colors.purple[500]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          CalenderPage(hospitalId: widget.hospitalId,isReferral: widget.isReferral)
                                  ));

                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: widget.isReferral ? null : CustomBottomNavBarHospital(hospitalId: widget.hospitalId),
      floatingActionButton: widget.isReferral
          ? FloatingActionButton(
        onPressed: () {
          String selectedHospitalName =
              _hospitalDetails['hospitalName'] ?? 'Loading Hospital..';
          Navigator.pop(context, selectedHospitalName);
          Navigator.pop(context, selectedHospitalName);

          Future.delayed(const Duration(milliseconds: 300), () {
            if (widget.selectHealthFacility != null) {
              widget.selectHealthFacility!(selectedHospitalName);
            }
          });
        },
        child: const Icon(Icons.add),
        backgroundColor: Colors.teal,
      )
          : null,
    );
  }
}

class CardButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const CardButton({
    super.key,
    required this.title,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    bool isPhysicians = title == 'Physicians';

    return Card(
      elevation: 12,
      shadowColor: Colors.black.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: isPhysicians
              ? MediaQuery.of(context).size.width * 0.7
              : MediaQuery.of(context).size.width * 0.4,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: isPhysicians
                ? _buildHorizontalLayout()
                : _buildVerticalLayout(),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalLayout() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            size: 36,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap to explore',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.arrow_forward_ios,
          color: Colors.white.withOpacity(0.8),
          size: 22,
        ),
      ],
    );
  }

  Widget _buildVerticalLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 32,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Tap',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ],
    );
  }
}
