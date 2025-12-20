import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'services.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirestoreService _db = FirestoreService();
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String _adminName = "Admin";

  @override
  void initState() {
    super.initState();
    // Get Admin Name from Firebase Auth
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      _adminName = user.displayName!;
    }
  }

  // --- LOGOUT DIALOG ---
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to exit?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
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

  // --- HELPER: GET AUTO SLOT ---
  String _getNextAvailableSlot(List<Patient> patients) {
    Set<int> usedSlots = patients.map((p) => int.tryParse(p.slotNumber) ?? 999).toSet();
    for (int i = 1; i <= 24; i++) {
      if (!usedSlots.contains(i)) {
        return i.toString();
      }
    }
    return "Full";
  }

  // --- ADD / EDIT DIALOG (Auto Slot) ---
  void _showPatientDialog({
    Patient? patientToEdit,
    required List<Patient> existingPatients,
  }) {
    final bool isEditing = patientToEdit != null;
    final nameCtrl = TextEditingController(text: isEditing ? patientToEdit.name : '');
    final ageCtrl = TextEditingController(text: isEditing ? patientToEdit.age.toString() : '');
    String gender = isEditing ? patientToEdit.gender : "Male";
    
    // Auto Slot Logic
    String assignedSlot = isEditing 
        ? patientToEdit.slotNumber 
        : _getNextAvailableSlot(existingPatients);

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
            bool isSaving = false;

            void addAlarm() {
              if (tempAlarms.length < 3) {
                setState(() {
                  tempAlarms.add({'time': '08:00', 'meds': <String>[]});
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Max 3 alarms allowed")));
              }
            }

            void addMedication(int alarmIndex) {
              if (tempAlarms[alarmIndex]['meds'].length < 5) {
                TextEditingController medInput = TextEditingController();
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Add Medication"),
                    content: TextField(
                      controller: medInput,
                      decoration: const InputDecoration(hintText: "Medication Name"),
                      autofocus: true,
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
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
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              insetPadding: const EdgeInsets.all(20),
              title: Text(isEditing ? "Edit Patient" : "Add Patient", style: const TextStyle(color: Color(0xFF1565C0))),
              content: SizedBox(
                width: dialogWidth,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // INFO
                        TextFormField(
                          controller: nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          validator: (v) => v!.isEmpty ? "Required" : null,
                          decoration: const InputDecoration(labelText: "Full Name", prefixIcon: Icon(Icons.person)),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: ageCtrl,
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isEmpty ? "Required" : null,
                          decoration: const InputDecoration(labelText: "Age", prefixIcon: Icon(Icons.calendar_today)),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: gender,
                          decoration: const InputDecoration(labelText: "Gender", prefixIcon: Icon(Icons.male)),
                          items: ["Male", "Female"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (v) => gender = v!,
                        ),
                        const SizedBox(height: 10),
                        
                        // AUTO ASSIGNED SLOT DISPLAY
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[400]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.grid_view, color: Colors.grey),
                              const SizedBox(width: 10),
                              Text(
                                "Slot Assigned: $assignedSlot",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),

                        const Divider(height: 30),
                        // ALARMS
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Alarms (Max 3)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                            if (tempAlarms.length < 3)
                              IconButton(onPressed: addAlarm, icon: const Icon(Icons.add_circle, color: Color(0xFF1565C0))),
                          ],
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
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time, size: 18, color: Color(0xFF1565C0)),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () async {
                                          TimeOfDay? t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 8, minute: 0));
                                          if (t != null) {
                                            String h = t.hour.toString().padLeft(2, '0');
                                            String m = t.minute.toString().padLeft(2, '0');
                                            setState(() => tempAlarms[index]['time'] = "$h:$m");
                                          }
                                        },
                                        child: Text(alarm['time'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
                                      ),
                                      const Spacer(),
                                      IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => setState(() => tempAlarms.removeAt(index))),
                                    ],
                                  ),
                                  const Divider(),
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      ...meds.map((m) => Chip(label: Text(m, style: const TextStyle(fontSize: 11)), backgroundColor: Colors.white, onDeleted: () => setState(() => meds.remove(m)))),
                                      if (meds.length < 5) ActionChip(label: const Text("+ Med"), backgroundColor: Colors.white, onPressed: () => addMedication(index)),
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
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
                  onPressed: isSaving ? null : () async {
                    if (formKey.currentState!.validate()) {
                      if (assignedSlot == "Full") {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No slots available!")));
                         return;
                      }
                      setState(() => isSaving = true);
                      List<AlarmModel> finalAlarms = tempAlarms.map((a) {
                        return AlarmModel(
                          timeOfDay: a['time'],
                          isActive: true,
                          medications: (a['meds'] as List<String>).map((mName) => Medication(name: mName)).toList(),
                        );
                      }).toList();

                      try {
                        if (isEditing) {
                          await _db.updatePatient(patientToEdit!, nameCtrl.text, int.parse(ageCtrl.text), assignedSlot, gender, finalAlarms);
                        } else {
                          await _db.addPatient(nameCtrl.text, int.parse(ageCtrl.text), assignedSlot, gender, finalAlarms);
                        }
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEditing ? "Updated" : "Added successfully"), backgroundColor: Colors.green));
                        }
                      } catch (e) {
                        setState(() => isSaving = false);
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                      }
                    }
                  },
                  child: isSaving ? const CircularProgressIndicator(color: Colors.white) : Text(isEditing ? "Update" : "Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- DELETE CONFIRMATION ---
  void _confirmDelete(String id, String name) {
     showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Patient"),
        content: Text("Are you sure you want to remove $name?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              _db.deletePatient(id);
              Navigator.pop(ctx);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  // --- STATS GRAPH WIDGET (PAGE 1) ---
  Widget _buildStatsPage(List<Patient> patients) {
    int totalPatients = patients.length;
    int skippedCount = 0;
    int takenCount = 0;
    int pendingCount = 0;

    for (var p in patients) {
      for (var a in p.alarms) {
        for (var m in a.medications) {
          if (m.status == 'skipped') skippedCount++;
          else if (m.status == 'taken') takenCount++;
          else pendingCount++;
        }
      }
    }
    
    // Prevent 0 division
    if (totalPatients == 0 && skippedCount == 0 && takenCount == 0 && pendingCount == 0) pendingCount = 1;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Overview", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 20),
          
          // Welcome Admin Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF64B5F6)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Welcome back,", style: TextStyle(color: Colors.white70, fontSize: 16)),
                Text(_adminName, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.people, color: Colors.white),
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("$totalPatients", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        const Text("Total Patients", style: TextStyle(color: Colors.white70)),
                      ],
                    )
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          const Text("Medication Status", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: [
                        PieChartSectionData(value: takenCount.toDouble(), color: Colors.green, radius: 30, showTitle: false),
                        PieChartSectionData(value: skippedCount.toDouble(), color: Colors.orange, radius: 30, showTitle: false),
                        PieChartSectionData(value: pendingCount.toDouble(), color: Colors.grey[300], radius: 25, showTitle: false),
                      ],
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendItem(Colors.green, "Taken ($takenCount)"),
                    const SizedBox(height: 10),
                    _buildLegendItem(Colors.orange, "Skipped ($skippedCount)"),
                    const SizedBox(height: 10),
                    _buildLegendItem(Colors.grey[300]!, "Pending ($pendingCount)"),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        CircleAvatar(radius: 6, backgroundColor: color),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  // --- PATIENTS LIST WIDGET (PAGE 2) ---
  Widget _buildPatientsPage(List<Patient> patients) {
    if (patients.isEmpty) {
      return const Center(child: Text("No patients found."));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      itemCount: patients.length,
      itemBuilder: (context, index) {
        final p = patients[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              radius: 25,
              backgroundColor: const Color(0xFFE3F2FD),
              child: Text(p.slotNumber, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
            ),
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${p.age} yrs • ${p.gender} • ${p.alarms.length} Alarms"),
            onTap: () => _showPatientDialog(patientToEdit: p, existingPatients: patients),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmDelete(p.id!, p.name),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Patient>>(
      stream: _db.getPatients(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final patients = snapshot.data!;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F9FF),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: const Text("PillPal Admin", style: TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
            actions: [
              IconButton(icon: const Icon(Icons.description_outlined, color: Colors.grey), onPressed: () => _db.generateReport(patients, context)),
              IconButton(icon: const Icon(Icons.logout, color: Colors.grey), onPressed: _confirmLogout),
            ],
          ),
          body: PageView(
            controller: _pageController,
            onPageChanged: (idx) => setState(() => _currentPage = idx),
            children: [
              _buildStatsPage(patients),
              _buildPatientsPage(patients),
            ],
          ),
          floatingActionButton: _currentPage == 1 // Only show FAB on Patient Page
              ? FloatingActionButton(
                  onPressed: () => _showPatientDialog(existingPatients: patients),
                  backgroundColor: const Color(0xFF1565C0),
                  child: const Icon(Icons.add, color: Colors.white),
                )
              : null,
          bottomNavigationBar: BottomAppBar(
             height: 60,
             child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceAround,
               children: [
                 IconButton(
                   icon: Icon(Icons.dashboard, color: _currentPage == 0 ? const Color(0xFF1565C0) : Colors.grey),
                   onPressed: () => _pageController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                 ),
                 IconButton(
                   icon: Icon(Icons.people, color: _currentPage == 1 ? const Color(0xFF1565C0) : Colors.grey),
                   onPressed: () => _pageController.animateToPage(1, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                 ),
                 IconButton(
                   icon: const Icon(Icons.devices, color: Colors.grey),
                   onPressed: () => Navigator.pushNamed(context, '/kiosk'),
                 ),
               ],
             ),
          ),
        );
      },
    );
  }
}