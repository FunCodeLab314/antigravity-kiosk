import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirestoreService _db = FirestoreService();

  // --- LOGOUT DIALOG ---
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to exit the admin panel?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              FirebaseAuth.instance.signOut();
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- DELETE DIALOG ---
  void _confirmDelete(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Patient"),
        content: Text(
          "Are you sure you want to remove $name? This cannot be undone.",
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              _db.deletePatient(id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("$name deleted"),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  // --- ADD / EDIT DIALOG (UPDATED: Multiple Alarms) ---
  void _showPatientDialog({
    Patient? patientToEdit,
    required List<Patient> existingPatients,
  }) {
    final bool isEditing = patientToEdit != null;

    // Core Controllers
    final nameCtrl = TextEditingController(
      text: isEditing ? patientToEdit.name : '',
    );
    final ageCtrl = TextEditingController(
      text: isEditing ? patientToEdit.age.toString() : '',
    );
    final slotCtrl = TextEditingController(
      text: isEditing ? patientToEdit.slotNumber : '',
    );
    String gender = isEditing ? patientToEdit.gender : "Male";

    // --- TEMPORARY ALARM DATA MANAGEMENT ---
    List<Map<String, dynamic>> tempAlarms = [];

    if (isEditing) {
      for (var alarm in patientToEdit.alarms) {
        tempAlarms.add({
          'time': alarm.timeOfDay,
          'meds': alarm.medications.map((m) => m.name).toList(),
        });
      }
    }

    final formKey = GlobalKey<FormState>();
    double dialogWidth = MediaQuery.of(context).size.width * 0.9;
    if (dialogWidth > 500) dialogWidth = 500;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            // --- Helper: Add New Alarm ---
            void addAlarm() {
              if (tempAlarms.length < 3) {
                setState(() {
                  tempAlarms.add({'time': '08:00', 'meds': <String>[]});
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Max 3 alarms allowed")),
                );
              }
            }

            // --- Helper: Add Med to Alarm ---
            void addMedication(int alarmIndex) {
              if (tempAlarms[alarmIndex]['meds'].length < 5) {
                TextEditingController medInput = TextEditingController();
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Add Medication"),
                    content: TextField(
                      controller: medInput,
                      decoration: const InputDecoration(
                        hintText: "Medication Name",
                      ),
                      autofocus: true,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (medInput.text.isNotEmpty) {
                            setState(() {
                              tempAlarms[alarmIndex]['meds'].add(medInput.text);
                            });
                            Navigator.pop(context);
                          }
                        },
                        child: const Text("Add"),
                      ),
                    ],
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Max 5 medications per alarm")),
                );
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              insetPadding: const EdgeInsets.all(20),
              title: Text(
                isEditing ? "Edit Patient" : "Add Patient",
                style: const TextStyle(color: Color(0xFF1565C0)),
              ),
              content: SizedBox(
                width: dialogWidth,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- PERSONAL INFO ---
                        const Text(
                          "Personal Info",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 10),

                        TextFormField(
                          controller: nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          validator: (v) => v!.isEmpty ? "Required" : null,
                          decoration: const InputDecoration(
                            labelText: "Full Name",
                            prefixIcon: Icon(Icons.person),
                          ),
                        ),
                        const SizedBox(height: 10),

                        TextFormField(
                          controller: ageCtrl,
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isEmpty ? "Required" : null,
                          decoration: const InputDecoration(
                            labelText: "Age",
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                        ),
                        const SizedBox(height: 10),

                        DropdownButtonFormField<String>(
                          value: gender,
                          decoration: const InputDecoration(
                            labelText: "Gender",
                            prefixIcon: Icon(Icons.male),
                          ),
                          items: ["Male", "Female"]
                              .map(
                                (s) =>
                                    DropdownMenuItem(value: s, child: Text(s)),
                              )
                              .toList(),
                          onChanged: (v) => gender = v!,
                        ),
                        const SizedBox(height: 10),

                        TextFormField(
                          controller: slotCtrl,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v!.isEmpty) return "Required";
                            bool isDuplicate = existingPatients.any((p) {
                              if (isEditing && p.id == patientToEdit.id)
                                return false;
                              return p.slotNumber == v;
                            });
                            if (isDuplicate) return "Slot $v taken!";
                            int? val = int.tryParse(v);
                            if (val == null || val < 1 || val > 24)
                              return "1-24 only";
                            return null;
                          },
                          decoration: const InputDecoration(
                            labelText: "Tray Slot (1-24)",
                            prefixIcon: Icon(Icons.grid_view),
                          ),
                        ),

                        const Divider(height: 30),

                        // --- ALARMS HEADER ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Alarms (Max 3)",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            if (tempAlarms.length < 3)
                              IconButton(
                                onPressed: addAlarm,
                                icon: const Icon(
                                  Icons.add_circle,
                                  color: Color(0xFF1565C0),
                                ),
                                tooltip: "Add Alarm",
                              ),
                          ],
                        ),

                        // --- ALARMS LIST ---
                        if (tempAlarms.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(10),
                            child: Text(
                              "No alarms set.",
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                              ),
                            ),
                          ),

                        ...tempAlarms.asMap().entries.map((entry) {
                          int index = entry.key;
                          Map<String, dynamic> alarm = entry.value;
                          List<String> meds = alarm['meds'];

                          return Card(
                            color: Colors.blue[50],
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Time Row
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time,
                                        size: 18,
                                        color: Color(0xFF1565C0),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () async {
                                          TimeOfDay? t = await showTimePicker(
                                            context: context,
                                            initialTime: const TimeOfDay(
                                              hour: 8,
                                              minute: 0,
                                            ),
                                          );
                                          if (t != null) {
                                            String h = t.hour
                                                .toString()
                                                .padLeft(2, '0');
                                            String m = t.minute
                                                .toString()
                                                .padLeft(2, '0');
                                            setState(() {
                                              tempAlarms[index]['time'] =
                                                  "$h:$m";
                                            });
                                          }
                                        },
                                        child: Text(
                                          alarm['time'],
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1565C0),
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          setState(
                                            () => tempAlarms.removeAt(index),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  const Divider(),
                                  // Meds List
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      ...meds.map(
                                        (m) => Chip(
                                          label: Text(
                                            m,
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                          backgroundColor: Colors.white,
                                          onDeleted: () {
                                            setState(() => meds.remove(m));
                                          },
                                        ),
                                      ),
                                      if (meds.length < 5)
                                        ActionChip(
                                          label: const Text("+ Med"),
                                          backgroundColor: Colors.white,
                                          onPressed: () => addMedication(index),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      // Conversion Logic: UI Maps -> Services Models
                      List<AlarmModel> finalAlarms = tempAlarms.map((a) {
                        return AlarmModel(
                          timeOfDay: a['time'],
                          isActive: true,
                          medications: (a['meds'] as List<String>)
                              .map((mName) => Medication(name: mName))
                              .toList(),
                        );
                      }).toList();

                      try {
                        if (isEditing) {
                          await _db.updatePatient(
                            patientToEdit!,
                            nameCtrl.text,
                            int.parse(ageCtrl.text),
                            slotCtrl.text,
                            gender,
                            finalAlarms,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Updated successfully"),
                                backgroundColor: Colors.blue,
                              ),
                            );
                          }
                        } else {
                          await _db.addPatient(
                            nameCtrl.text,
                            int.parse(ageCtrl.text),
                            slotCtrl.text,
                            gender,
                            finalAlarms,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Added successfully"),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }
                        if (context.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Error: $e"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: Text(isEditing ? "Update" : "Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- FIXED NAV BUTTON (Mobile Optimized) ---
  Widget _buildNavButton(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF1565C0), size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFF1565C0),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        title: const Text(
          "PillPal Admin",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1565C0),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _confirmLogout),
        ],
      ),
      body: StreamBuilder<List<Patient>>(
        stream: _db.getPatients(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final patients = snapshot.data!;

          if (patients.isEmpty) {
            return const Center(child: Text("No patients yet. Tap + to add."));
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                itemCount: patients.length,
                itemBuilder: (context, index) {
                  final p = patients[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: InkWell(
                        onTap: () => _showPatientDialog(
                          patientToEdit: p,
                          existingPatients: patients,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            radius: 28,
                            backgroundColor: const Color(0xFFE3F2FD),
                            child: Text(
                              p.slotNumber,
                              style: const TextStyle(
                                color: Color(0xFF1565C0),
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          title: Text(
                            p.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                children: [
                                  _buildTag("${p.age} yrs"),
                                  _buildTag(p.gender),
                                  _buildTag("${p.alarms.length} Alarms"),
                                ],
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => _confirmDelete(p.id!, p.name),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: StreamBuilder<List<Patient>>(
        stream: _db.getPatients(),
        builder: (context, snapshot) {
          return FloatingActionButton(
            onPressed: () =>
                _showPatientDialog(existingPatients: snapshot.data ?? []),
            backgroundColor: const Color(0xFF1565C0),
            child: const Icon(Icons.add, color: Colors.white, size: 30),
          );
        },
      ),
      // --- FIXED NAVBAR WITH PROPER HEIGHT ---
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.white,
        height: 60,
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildNavButton(Icons.description_outlined, "Report", () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Generating PDF..."),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              final patients = await _db.getPatients().first;
              if (context.mounted) _db.generateReport(patients, context);
            }),
            const SizedBox(width: 80), // Space for FAB
            _buildNavButton(
              Icons.devices,
              "Kiosk",
              () => Navigator.pushNamed(context, '/kiosk'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}
