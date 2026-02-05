import 'package:flutter/material.dart';
import '../domain/meeting_model.dart';

class CreateMeetingScreen extends StatefulWidget {
  const CreateMeetingScreen({super.key});

  @override
  State<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends State<CreateMeetingScreen> {
  final _titleController = TextEditingController();
  final _timeController = TextEditingController();
  final List<AgendaItemData> _agendaItems = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Create New Agenda", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          TextButton(
            onPressed: _saveMeeting,
            child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputCard(
              label: "Meeting Title",
              hint: "e.g. Client Sync: Alpha Corp",
              controller: _titleController,
            ),
            const SizedBox(height: 16),
            _buildInputCard(
              label: "Time Range",
              hint: "e.g. 10:30 AM - 11:30 AM",
              controller: _timeController,
              icon: Icons.access_time,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Agenda Items",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: _showAddAgendaItemSheet,
                  icon: const Icon(Icons.add_circle, color: Color(0xFF4C7BF3), size: 30),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_agendaItems.isEmpty)
              _buildEmptyState()
            else
              ..._agendaItems.map((item) => _buildDraftItemCard(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard({required String label, required String hint, required TextEditingController controller, IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.black87, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            suffixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
            filled: true,
            fillColor: const Color(0xFFF6F7F9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDraftItemCard(AgendaItemData item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFEDF2FE), borderRadius: BorderRadius.circular(8)),
            child: Text(item.duration, style: const TextStyle(color: Color(0xFF4C7BF3), fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(item.subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () {
              setState(() {
                _agendaItems.remove(item);
              });
            },
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(30),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
      ),
      child: const Text("No items yet.\nTap + to add an agenda topic.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
    );
  }

  void _showAddAgendaItemSheet() {
    String title = "";
    String subtitle = "";
    String duration = "15m";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Add Agenda Topic", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                style: const TextStyle(color: Colors.black87, fontSize: 16),
                decoration: const InputDecoration(
                  labelText: "Topic Title (e.g. Design Review)",
                  labelStyle: TextStyle(color: Colors.grey),
                ),
                onChanged: (val) => title = val,
              ),
              TextField(
                style: const TextStyle(color: Colors.black87, fontSize: 16),
                decoration: const InputDecoration(
                  labelText: "Description",
                  labelStyle: TextStyle(color: Colors.grey),
                ),
                onChanged: (val) => subtitle = val,
              ),
              TextField(
                style: const TextStyle(color: Colors.black87, fontSize: 16),
                decoration: const InputDecoration(
                  labelText: "Duration (e.g. 15m)",
                  labelStyle: TextStyle(color: Colors.grey),
                ),
                onChanged: (val) => duration = val,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4C7BF3),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  if (title.isNotEmpty) {
                    setState(() {
                      _agendaItems.add(AgendaItemData(
                        title: title,
                        subtitle: subtitle,
                        duration: duration,
                      ));
                    });
                    Navigator.pop(context);
                  }
                },
                child: const Text("Add Item", style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        );
      },
    );
  }

  void _saveMeeting() {
    final newMeeting = MeetingData(
      title: _titleController.text,
      timeRange: _timeController.text,
      items: _agendaItems,
    );
    Navigator.pop(context, newMeeting);
  }
}
