import 'package:flutter/material.dart';
import '../Home/Widgets/organization_list_view.dart';
class GeneralHospitalPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hospitals'),
        centerTitle: true,
        backgroundColor: Colors.teal,
      ),
      body: OrganizationListView(
        showSearchBar: true,
        isReferral: false,
      ),
    );
  }
}
