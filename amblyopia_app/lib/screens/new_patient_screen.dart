import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/screening_provider.dart';
import '../services/location_service.dart';
import 'screening/screening_controller.dart';

class NewPatientScreen extends StatefulWidget {
  final String villageId;
  final String villageName;

  const NewPatientScreen({
    super.key,
    required this.villageId,
    required this.villageName,
  });

  @override
  State<NewPatientScreen> createState() => _NewPatientScreenState();
}

class _NewPatientScreenState extends State<NewPatientScreen> {
  String _selectedAgeGroup = 'child';
  Position? _position;
  bool _locationLoading = true;
  String _locationLabel = 'Locating...';

  final List<_AgeGroupOption> _ageGroups = const [
    _AgeGroupOption('infant', '👶', 'INFANT', '< 1 year'),
    _AgeGroupOption('child', '🧒', 'CHILD', '1–18 years'),
    _AgeGroupOption('adult', '👨', 'ADULT', '18–60 years'),
    _AgeGroupOption('elderly', '👴', 'ELDERLY', '60+ years'),
  ];

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    final pos = await LocationService.getCurrentPosition();
    if (mounted) {
      setState(() {
        _position = pos;
        _locationLoading = false;
        _locationLabel = pos != null
            ? 'Coimbatore, Tamil Nadu'
            : 'Location unavailable';
      });
    }
  }

  Future<void> _onStart() async {
    final provider = context.read<ScreeningProvider>();
    provider.reset();

    await provider.startSession(
      ageGroup: _selectedAgeGroup,
      villageId: widget.villageId,
      lat: _position?.latitude ?? 11.0168,
      lng: _position?.longitude ?? 76.9558,
    );

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ScreeningController(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New Patient',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text(
              widget.villageName,
              style: const TextStyle(color: Color(0xFF90CAF9), fontSize: 12),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Age group selector
            const Text(
              'Select Age Group',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: _ageGroups.map((ag) {
                final selected = _selectedAgeGroup == ag.id;
                return GestureDetector(
                  onTap: () => setState(() => _selectedAgeGroup = ag.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF1565C0).withOpacity(0.3)
                          : const Color(0xFF0D1B2A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF00E5FF)
                            : const Color(0xFF1A2A3A),
                        width: selected ? 2 : 1,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF00E5FF).withOpacity(0.2),
                                blurRadius: 12,
                                spreadRadius: 1,
                              )
                            ]
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(ag.emoji, style: const TextStyle(fontSize: 28)),
                        const SizedBox(height: 6),
                        Text(
                          ag.label,
                          style: TextStyle(
                            color: selected
                                ? const Color(0xFF00E5FF)
                                : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          ag.sublabel,
                          style: const TextStyle(
                              color: Color(0xFF546E7A), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            // GPS card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1A2A3A)),
              ),
              child: Row(
                children: [
                  Icon(
                    _position != null ? Icons.location_on : Icons.location_searching,
                    color: _position != null ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _locationLoading ? 'Locating...' : _locationLabel,
                      style: TextStyle(
                        color: _position != null ? Colors.white : Colors.orange,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (_locationLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.orange, strokeWidth: 2),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Test sequence preview
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1A2A3A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Screening runs automatically:',
                    style: TextStyle(
                        color: Color(0xFF90CAF9),
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  _TestStep(n: '1', icon: '👁', label: 'Gaze Tracking', duration: '30 sec'),
                  SizedBox(height: 6),
                  _TestStep(n: '2', icon: '🔤', label: 'Snellen Chart', duration: 'voice'),
                  SizedBox(height: 6),
                  _TestStep(n: '3', icon: '🟢', label: 'Red-Green Test', duration: '30 sec'),
                ],
              ),
            ),
            if (_selectedAgeGroup == 'infant') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2000),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hirschberg test will run automatically for infant',
                        style: TextStyle(color: Colors.amber, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
            // Start button
            SizedBox(
              height: 58,
              child: ElevatedButton.icon(
                onPressed: _locationLoading ? null : _onStart,
                icon: const Icon(Icons.play_circle_fill, size: 28),
                label: const Text(
                  'START SCREENING',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF1A2A3A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 6,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _AgeGroupOption {
  final String id;
  final String emoji;
  final String label;
  final String sublabel;

  const _AgeGroupOption(this.id, this.emoji, this.label, this.sublabel);
}

class _TestStep extends StatelessWidget {
  final String n;
  final String icon;
  final String label;
  final String duration;

  const _TestStep({
    required this.n,
    required this.icon,
    required this.label,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1565C0).withOpacity(0.5),
          ),
          child: Center(
            child: Text(n, style: const TextStyle(color: Colors.white, fontSize: 11)),
          ),
        ),
        const SizedBox(width: 8),
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
        Text(
          duration,
          style: const TextStyle(color: Color(0xFF546E7A), fontSize: 12),
        ),
      ],
    );
  }
}
