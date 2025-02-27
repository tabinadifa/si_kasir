import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class OmzetPertahunScreen extends StatefulWidget {
  const OmzetPertahunScreen({super.key});

  @override
  State<OmzetPertahunScreen> createState() => _OmzetPertahunScreenState();
}

class _OmzetPertahunScreenState extends State<OmzetPertahunScreen> {
  final Map<String, List<double>> yearlyData = {
    '2023': [9.0, 9.3, 8.7, 9.4, 9.1, 8.9, 9.5, 8.8, 9.2, 8.9, 9.1, 9.7],
    '2024': [8.3, 9.2, 8.8, 9.5, 8.7, 9.0, 9.3, 8.9, 9.4, 9.1, 8.6, 9.6],
    '2025': [8.8, 9.0, 8.5, 9.2, 8.9, 9.1, 9.4, 8.7, 9.3, 9.0, 8.8, 9.5],
  };

  int selectedYear = DateTime.now().year;
  final int startYear = DateTime.now().year - 5;
  final int endYear = DateTime.now().year;
  int _touchedIndex = -1;

  Widget _buildBarChart(List<String> months, List<double> data) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 1.7,
        child: Padding(
          padding: const EdgeInsets.only(top: 30.0, right: 30.0),
          child: BarChart(
            BarChartData(
              groupsSpace: 12,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${months[group.x]}\n${rod.toY.toStringAsFixed(1)}M',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                  tooltipPadding: const EdgeInsets.all(8),
                  tooltipMargin: 8,
                  tooltipRoundedRadius: 8,
                  getTooltipColor: (group) => const Color(0xFF133E87),
                ),
                touchCallback: (event, response) {
                  if (response?.spot != null) {
                    setState(() {
                      _touchedIndex = response!.spot!.touchedBarGroupIndex;
                    });
                  }
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          months[value.toInt()],
                          style: TextStyle(
                            color: _touchedIndex == value.toInt()
                                ? const Color(0xFF133E87)
                                : Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                    reservedSize: 40,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 2,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toInt()}M',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      );
                    },
                    reservedSize: 40,
                  ),
                ),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 2,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey[200],
                  strokeWidth: 1,
                ),
              ),
              barGroups: List.generate(months.length, (index) {
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: data[index],
                      gradient: _barsGradient,
                      width: 20,
                      borderRadius: BorderRadius.circular(4),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: 10,
                        color: Colors.grey[100],
                      ),
                    ),
                  ],
                );
              }),
              alignment: BarChartAlignment.spaceAround,
              maxY: 10,
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: 10,
                    color: Colors.grey[300],
                    strokeWidth: 1,
                    dashArray: [8],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  LinearGradient get _barsGradient => LinearGradient(
        colors: [
          const Color(0xFF133E87),
          const Color(0xFF4B7DD1),
        ],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      );

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required String title,
    required String month,
    required String amount,
    required bool isSmallScreen,
  }) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: isSmallScreen ? 20 : 24),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: iconColor,
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 14 : 16,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            month,
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF133E87),
            ),
          ),
          SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: isSmallScreen ? 14 : 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Color(0xFF133E87),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Tahun',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          DropdownButton<int>(
            value: selectedYear,
            dropdownColor: Color(0xFF133E87),
            icon: Icon(Icons.arrow_drop_down, color: Colors.white),
            underline: SizedBox(),
            style: TextStyle(color: Colors.white, fontSize: 16),
            onChanged: (int? newValue) {
              setState(() {
                selectedYear = newValue!;
              });
            },
            items: List.generate(
              endYear - startYear + 1,
              (index) => DropdownMenuItem<int>(
                value: startYear + index,
                child: Text(
                  (startYear + index).toString(),
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton() {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: Text(
            'Cetak Excel',
            style: TextStyle(
              color: Color(0xFF133E87),
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allMonths = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Ags',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ];
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Omzet Pertahun',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _buildExportButton(),
          ),
        ],
        backgroundColor: Color(0xFF133E87),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildYearDropdown(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: SizedBox(
                  height: 400,
                  child: _buildBarChart(
                      allMonths,
                      yearlyData[selectedYear.toString()] ??
                          List.generate(12, (index) => 0.0)),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16, vertical: 16),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.bar_chart,
                          color: Color(0xFF133E87),
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Total Omset',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Rp71.800.000.000',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF133E87),
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 20 : 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return constraints.maxWidth < 600
                            ? Column(
                                children: [
                                  _buildStatCard(
                                    icon: Icons.trending_up,
                                    iconColor: Colors.blue[700]!,
                                    backgroundColor: Colors.blue[50]!,
                                    title: 'Bulan tertinggi',
                                    month: 'Juni',
                                    amount: 'Rp10.800.000.000',
                                    isSmallScreen: isSmallScreen,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildStatCard(
                                    icon: Icons.trending_down,
                                    iconColor: Colors.red[700]!,
                                    backgroundColor: Colors.red[50]!,
                                    title: 'Bulan terendah',
                                    month: 'Januari',
                                    amount: 'Rp8.800.000.000',
                                    isSmallScreen: isSmallScreen,
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: _buildStatCard(
                                      icon: Icons.trending_up,
                                      iconColor: Colors.blue[700]!,
                                      backgroundColor: Colors.blue[50]!,
                                      title: 'Bulan tertinggi',
                                      month: 'Juni',
                                      amount: 'Rp10.800.000.000',
                                      isSmallScreen: isSmallScreen,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildStatCard(
                                      icon: Icons.trending_down,
                                      iconColor: Colors.red[700]!,
                                      backgroundColor: Colors.red[50]!,
                                      title: 'Bulan terendah',
                                      month: 'Januari',
                                      amount: 'Rp8.800.000.000',
                                      isSmallScreen: isSmallScreen,
                                    ),
                                  ),
                                ],
                              );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() => runApp(MaterialApp(
      theme: ThemeData(
        primaryColor: const Color(0xFF133E87),
        scaffoldBackgroundColor: Colors.grey[50],
        fontFamily: 'Inter',
      ),
      home: OmzetPertahunScreen(),
      debugShowCheckedModeBanner: false,
    ));
