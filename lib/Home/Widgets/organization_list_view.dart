import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../Hospital/specialty_details.dart';

class OrganizationListView extends StatefulWidget {
  final bool showSearchBar;
  final bool isReferral;

  const OrganizationListView({Key? key, required this.showSearchBar,required this.isReferral}) : super(key: key);

  @override
  _OrganizationListViewState createState() => _OrganizationListViewState();
}

class _OrganizationListViewState extends State<OrganizationListView> {
  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.showSearchBar)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or city...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('Hospital').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              final hospitals = snapshot.data!.docs.where((doc) {
                final hospitalData = doc.data() as Map<String, dynamic>;
                final hospitalName = hospitalData['Hospital Name']?.toLowerCase() ?? '';
                final city = hospitalData['City']?.toLowerCase() ?? '';
                return hospitalName.contains(searchQuery) || city.contains(searchQuery);
              }).toList();

              return ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: hospitals.length,
                itemBuilder: (context, index) {
                  final hospital = hospitals[index];
                  final hospitalData = hospital.data() as Map<String, dynamic>;
                  final backgroundImage = hospitalData['Background Image'] ?? '';
                  final city = hospitalData['City'] ?? 'Unknown City';
                  final contact = hospitalData['Contact'] ?? 'No Contact Info';
                  final hospitalId = hospital.id;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SpecialtyDetails(hospitalId: hospitalId, isReferral: widget.isReferral,),
                        ),
                      );
                    },
                    child: HospitalCard(
                      backgroundImage: backgroundImage,
                      city: city,
                      contact: contact,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class HospitalCard extends StatelessWidget {
  final String backgroundImage;
  final String city;
  final String contact;

  const HospitalCard({
    Key? key,
    required this.backgroundImage,
    required this.city,
    required this.contact,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 5.0),
      elevation: 8.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(15.0)),
            child: Image.network(
              backgroundImage,
              height: 100,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, size: 100),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  city,
                  style: TextStyle(fontSize: 14.0, color: Colors.black87, fontWeight: FontWeight.bold),
                ),
                Text(
                  contact,
                  style: TextStyle(fontSize: 12.0, fontStyle: FontStyle.italic, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
