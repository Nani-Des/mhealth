import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { private, forum, experts }

class HealthInsightsPage extends StatefulWidget {
  const HealthInsightsPage({super.key});

  @override
  State<HealthInsightsPage> createState() => _HealthInsightsPageState();
}

class _HealthInsightsPageState extends State<HealthInsightsPage>
    with SingleTickerProviderStateMixin {
  MessageType _selectedType = MessageType.private;
  String _selectedRegion = 'All Regions';
  late AnimationController _animationController;
  late Animation<double> _animation;

  final List<String> ghanaRegions = [
    'All Regions',
    'Ahafo',
    'Ashanti',
    'Bono East',
    'Bono',
    'Central',
    'Eastern',
    'Greater Accra',
    'North East',
    'Northern',
    'Oti',
    'Savannah',
    'Upper East',
    'Upper West',
    'Volta',
    'Western North',
    'Western'
  ];

  final Map<String, List<String>> healthCategories = {
    'symptoms': [
      'fever', 'pain', 'cough', 'fatigue', 'headache', 'nausea',
      'dizziness', 'inflammation', 'rash', 'anxiety', 'malaria',
      'typhoid', 'cholera', 'diarrhea', 'vomiting'
    ],
    'conditions': [
      'diabetes', 'hypertension', 'asthma', 'arthritis', 'depression',
      'obesity', 'cancer', 'allergy', 'infection', 'insomnia',
      'sickle cell', 'tuberculosis', 'HIV', 'hepatitis', 'stroke'
    ],
    'treatments': [
      'medication', 'therapy', 'surgery', 'exercise', 'diet',
      'vaccination', 'rehabilitation', 'counseling', 'prescription', 'supplement',
      'traditional medicine', 'herbs', 'physiotherapy', 'immunization', 'antibiotics'
    ],
    'lifestyle': [
      'nutrition', 'fitness', 'sleep', 'stress', 'wellness',
      'meditation', 'diet', 'exercise', 'hydration', 'mindfulness',
      'traditional food', 'local diet', 'community', 'family health', 'work-life'
    ],
    'preventive': [
      'screening', 'checkup', 'vaccination', 'prevention', 'hygiene',
      'immunization', 'monitoring', 'assessment', 'testing', 'evaluation',
      'sanitation', 'clean water', 'mosquito nets', 'hand washing', 'nutrition'
    ]
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Insights'),
        backgroundColor: Colors.lightBlue,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRegionSelector(),
              const SizedBox(height: 16),
              _buildMessageTypeSelector(),
              const SizedBox(height: 16),
              _buildHealthTopicsChart(),
              const SizedBox(height: 16),
              _buildHealthTopicsPieChart(),
              _buildLegend(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegionSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: DropdownButtonFormField<String>(
          value: _selectedRegion,
          decoration: const InputDecoration(
            labelText: 'Select Region',
            border: InputBorder.none,
          ),
          items: ghanaRegions.map((String region) {
            return DropdownMenuItem(
              value: region,
              child: Text(region),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedRegion = newValue!;
              _animationController.reset();
              _animationController.forward();
            });
          },
        ),
      ),
    );
  }

  Widget _buildMessageTypeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SegmentedButton<MessageType>(
          segments: const [
            ButtonSegment(
              value: MessageType.private,
              label: Text('Private'),
              icon: Icon(Icons.chat),
            ),
            ButtonSegment(
              value: MessageType.forum,
              label: Text('Forum'),
              icon: Icon(Icons.forum),
            ),
            ButtonSegment(
              value: MessageType.experts,
              label: Text('Experts'),
              icon: Icon(Icons.medical_services),
            ),
          ],
          selected: {_selectedType},
          onSelectionChanged: (Set<MessageType> selected) {
            setState(() {
              _selectedType = selected.first;
              _animationController.reset();
              _animationController.forward();
            });
          },
        ),
      ),
    );
  }

  Widget _buildHealthTopicsChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Health Topics in $_selectedRegion',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 400,
              child: FutureBuilder<List<BarChartGroupData>>(
                future: _getBarGroups(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No data available'));
                  }

                  // Dynamically calculate maxY based on the highest bar value
                  double maxY = snapshot.data!
                      .map((group) => group.barRods.first.toY)
                      .reduce((a, b) => a > b ? a : b);

                  // Add a 20% buffer to the maxY to ensure bars don't touch the top
                  maxY = maxY > 0 ? maxY * 1.2 : 100;

                  return AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return BarChart(
                        BarChartData(
                          titlesData: FlTitlesData(
                            bottomTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                interval: maxY / 5, // Divide maxY into 5 intervals
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(fontSize: 12),
                                  );
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: const FlGridData(
                            show: true,
                            drawVerticalLine: false,
                          ),
                          alignment: BarChartAlignment.spaceAround,
                          maxY: maxY, // Use the dynamically calculated maxY
                          barGroups: snapshot.data!.map((group) {
                            return BarChartGroupData(
                              x: group.x,
                              barRods: [
                                BarChartRodData(
                                  toY: group.barRods.first.toY * _animation.value,
                                  color: group.barRods.first.color,
                                  width: 16,
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthTopicsPieChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Health Topics Distribution',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: FutureBuilder<List<PieChartSectionData>>(
                future: _getPieSections(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No data available'));
                  }

                  return AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return PieChart(
                        PieChartData(
                          sections: snapshot.data!.map((section) {
                            return PieChartSectionData(
                              value: section.value * _animation.value,
                              title: section.title,
                              color: section.color,
                              radius: section.radius,
                              titleStyle: section.titleStyle,
                            );
                          }).toList(),
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          children: healthCategories.keys.map((category) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  color: _getCategoryColor(category),
                ),
                const SizedBox(width: 4),
                Text(category.toUpperCase()),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('About Health Insights'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'This dashboard shows health-related topics discussed in:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('• Private Messages\n• Forum Posts\n• Expert Discussions'),
                const SizedBox(height: 16),
                const Text(
                  'Categories Analyzed:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...healthCategories.keys.map(
                      (category) => Text('• ${category.toUpperCase()}: '
                      '${healthCategories[category]!.take(5).join(", ")} and more...'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<List<BarChartGroupData>> _getBarGroups() async {
    Map<String, int> insights = await fetchHealthInsights();
    List<String> categories = healthCategories.keys.toList();

    return List.generate(categories.length, (index) {
      String category = categories[index];
      int totalCount = insights[category] ?? 0;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: totalCount.toDouble(),
            color: _getCategoryColor(category),
            width: 16,
          ),
        ],
      );
    });
  }

  Future<List<PieChartSectionData>> _getPieSections() async {
    Map<String, int> insights = await fetchHealthInsights();
    List<String> categories = healthCategories.keys.toList();
    List<PieChartSectionData> sections = [];

    for (int index = 0; index < categories.length; index++) {
      String category = categories[index];
      int totalCount = insights[category] ?? 0;

      if (totalCount > 0) {
        sections.add(
          PieChartSectionData(
            value: totalCount.toDouble(),
            title: category.toUpperCase(),
            color: _getCategoryColor(category),
            radius: 50,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        );
      }
    }

    return sections;
  }

  Color _getCategoryColor(String category) {
    final colors = {
      'symptoms': Colors.red[300]!,
      'conditions': Colors.blue[300]!,
      'treatments': Colors.green[300]!,
      'lifestyle': Colors.purple[300]!,
      'preventive': Colors.orange[300]!,
    };
    return colors[category] ?? Colors.grey;
  }

  Future<Map<String, int>> fetchHealthInsights() async {
    Query query = FirebaseFirestore.instance.collection('HealthInsights');
    if (_selectedRegion != 'All Regions') {
      query = query.where('region', isEqualTo: _selectedRegion);
    }
    query = query.where('messageType', isEqualTo: _selectedType.name);
    QuerySnapshot snapshot = await query.get();
    Map<String, int> topicCounts = {};

    for (var doc in snapshot.docs) {
      String category = doc['category'];
      int count = doc['count'];
      topicCounts[category] = (topicCounts[category] ?? 0) + count;
    }

    for (var category in healthCategories.keys) {
      if (!topicCounts.containsKey(category)) {
        topicCounts[category] = 0;
      }
    }

    return topicCounts;
  }
}
