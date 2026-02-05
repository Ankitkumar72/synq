import 'package:flutter/material.dart';
import '../domain/meeting_model.dart';

class MeetingAgendaScreen extends StatelessWidget {
  final MeetingData? data;
  
  const MeetingAgendaScreen({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    // Use provided data or fallback to sample data
    final meetingTitle = data?.title ?? "Client Sync: Alpha Corp";
    final meetingTime = data?.timeRange ?? "10:30 AM - 11:30 AM";
    final agendaItems = data?.items ?? [
      AgendaItemData(title: "Project Update", subtitle: "Reviewing Q3 milestones and blockers.", duration: "Now"),
      AgendaItemData(title: "Design Review", subtitle: "Walkthrough of new mobile flows.", duration: "15m"),
      AgendaItemData(title: "Next Steps", subtitle: "Assigning action items for the week.", duration: "5m"),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Meeting Agenda',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: const Color(0xFF4C7BF3),
        icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
        label: const Text(
          "Notes",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(meetingTitle, meetingTime),
            const SizedBox(height: 16),
            _buildParticipantsCard(),
            const SizedBox(height: 24),
            const Text(
              "Agenda Items",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            ...agendaItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _buildAgendaItem(
                isActive: index == 0,
                title: item.title,
                subtitle: item.subtitle,
                time: item.duration,
                hasChecklist: index == 0,
                isLast: index == agendaItems.length - 1,
              );
            }),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(String title, String timeRange) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: Color(0xFF4C7BF3)),
                    SizedBox(width: 6),
                    Text(
                      "IN PROGRESS",
                      style: TextStyle(
                        color: Color(0xFF4C7BF3),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.videocam_rounded, color: Color(0xFF4C7BF3)),
              )
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 18, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                timeRange,
                style: const TextStyle(
                    color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.timer_outlined, size: 18, color: Colors.grey),
              const SizedBox(width: 6),
              const Text(
                "1h",
                style: TextStyle(
                    color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildParticipantsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "PARTICIPANTS",
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "View all",
                style: TextStyle(
                  color: Colors.blue[600],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 120,
                height: 40,
                child: Stack(
                  children: [
                    _buildAvatar(0, "JD", Colors.grey[400]!),
                    _buildAvatar(25, "AS", Colors.blue[300]!),
                    _buildAvatar(50, "MR", Colors.black87),
                    Positioned(
                      left: 75,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Center(
                          child: Text("+2", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: Colors.black),
                label: const Text("Invite", style: TextStyle(color: Colors.black)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildAvatar(double left, String initials, Color color) {
    return Positioned(
      left: left,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Center(
          child: Text(
            initials,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildAgendaItem({
    required bool isActive,
    required String title,
    required String subtitle,
    required String time,
    bool hasChecklist = false,
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? const Color(0xFF4C7BF3) : Colors.transparent,
                  border: Border.all(
                    color: isActive ? const Color(0xFF4C7BF3) : Colors.grey[300]!,
                    width: 2,
                  ),
                ),
                child: isActive
                    ? Center(child: Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)))
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isActive ? const Color(0xFF4C7BF3).withAlpha(51) : Colors.grey[200],
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: isActive ? const EdgeInsets.all(16) : EdgeInsets.zero,
              decoration: isActive
                  ? BoxDecoration(
                      color: const Color(0xFFF6F7F9),
                      borderRadius: BorderRadius.circular(16),
                    )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isActive ? const Color(0xFF4C7BF3) : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                  if (hasChecklist) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildChecklistItem("Alpha launch metrics", true),
                          const SizedBox(height: 12),
                          _buildChecklistItem("User feedback loop", false),
                        ],
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String text, bool isChecked) {
    return Row(
      children: [
        Icon(
          isChecked ? Icons.check_circle : Icons.radio_button_checked,
          size: 20,
          color: isChecked ? Colors.green : const Color(0xFF4C7BF3),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            decoration: isChecked ? TextDecoration.lineThrough : null,
            color: isChecked ? Colors.grey : Colors.black87,
          ),
        ),
      ],
    );
  }
}
