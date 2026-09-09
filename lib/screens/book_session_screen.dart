import 'package:flutter/material.dart';
import '../core/navigation.dart';
import '../core/theme/app_theme.dart';
import '../services/db_service.dart';

class BookSessionScreen extends StatefulWidget {
  const BookSessionScreen({super.key});

  @override
  State<BookSessionScreen> createState() => _BookSessionScreenState();
}

class _BookSessionScreenState extends State<BookSessionScreen> {
  String _sessionType = 'voice'; // 'in-person' or 'voice'
  int _selectedDayOffset = 1; // 0: Today, 1: Tomorrow, 2: Day after
  int _selectedSlotIndex = 2; // 14:30 hrs
  final _topicController = TextEditingController(text: 'Routine operational decompression');
  final _db = DbService();
  bool _booking = false;

  final List<String> _timeSlots = [
    '09:30 - 10:15 hrs',
    '11:00 - 11:45 hrs',
    '14:30 - 15:15 hrs',
    '16:00 - 16:45 hrs',
    '19:00 - 19:45 hrs',
  ];

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _confirmBooking() async {
    setState(() => _booking = true);

    final appointmentDate = DateTime.now().add(Duration(days: _selectedDayOffset));
    final slot = _timeSlots[_selectedSlotIndex];

    await _db.bookCounseling(
      sessionType: _sessionType,
      date: appointmentDate,
      timeSlot: slot,
      topic: _topicController.text.trim(),
    );

    setState(() => _booking = false);

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppColors.surface,
          title: const Row(
            children: [
              Icon(Icons.event_available, color: AppColors.secondary),
              SizedBox(width: 8),
              Text('Session Scheduled', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Type: ${_sessionType == 'voice' ? 'Secure Voice Line' : 'In-person Unit Visit'}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primary),
              ),
              const SizedBox(height: 4),
              Text('Time: $slot', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              const Text(
                'Your request has been routed directly to the duty Welfare Officer in complete confidence. It is never exposed through your unit chain of command.',
                style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                context.backOr('/home');
              },
              child: const Text('Return Home'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.backOr('/home'),
        ),
        title: const Text('Book Session', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: AppColors.onSurfaceVariant),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sessions are confidential consultations with certified Welfare Officers.')),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reassurance Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user, color: AppColors.secondaryFixed, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Discreet Support Pathway',
                            style: TextStyle(color: AppColors.secondaryFixed, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Strictly confidential. No command-hierarchy visibility.',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Step 1: Session Type
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Session Type', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  Text('Step 1 of 3', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _typeCard(
                      type: 'in-person',
                      title: 'In-person',
                      subtitle: 'Unit Visit',
                      icon: Icons.meeting_room_outlined,
                      isSelected: _sessionType == 'in-person',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _typeCard(
                      type: 'voice',
                      title: 'Voice Line',
                      subtitle: 'Secure audio',
                      icon: Icons.phone_in_talk_outlined,
                      isSelected: _sessionType == 'voice',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Step 2: Date Selection
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Select Date', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  Text('Step 2 of 3', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _dateChip('Today', 0),
                  const SizedBox(width: 8),
                  _dateChip('Tomorrow', 1),
                  const SizedBox(width: 8),
                  _dateChip('Day After', 2),
                ],
              ),
              const SizedBox(height: 24),

              // Step 3: Time Slot
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Preferred Time Slot', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  Text('Step 3 of 3', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_timeSlots.length, (idx) {
                  final isSelected = _selectedSlotIndex == idx;
                  return ChoiceChip(
                    label: Text(_timeSlots[idx], style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    selected: isSelected,
                    selectedColor: AppColors.secondaryContainer,
                    labelStyle: TextStyle(color: isSelected ? AppColors.onSecondaryContainer : AppColors.primary),
                    backgroundColor: AppColors.surfaceContainerLowest,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    onSelected: (_) => setState(() => _selectedSlotIndex = idx),
                  );
                }),
              ),
              const SizedBox(height: 20),

              // Topic Note Input
              const Text('Consultation Focus (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _topicController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Workload strain, sleep rhythm, family stress...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(12),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 28),

              // Confirm Booking Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _booking ? null : _confirmBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _booking
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Confirm Confidential Booking', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            SizedBox(width: 8),
                            Icon(Icons.check_circle_outline, size: 18),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeCard({
    required String type,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
  }) {
    return Material(
      color: isSelected ? AppColors.secondaryContainer : AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _sessionType = type),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.surfaceContainerLowest : AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isSelected ? AppColors.onSecondaryContainer : AppColors.primary,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? AppColors.onSecondaryContainer.withOpacity(0.8) : AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateChip(String label, int dayOffset) {
    final isSelected = _selectedDayOffset == dayOffset;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: AppColors.secondaryContainer,
      labelStyle: TextStyle(color: isSelected ? AppColors.onSecondaryContainer : AppColors.primary),
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (_) => setState(() => _selectedDayOffset = dayOffset),
    );
  }
}
