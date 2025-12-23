
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/service_providers.dart';
import '../providers/data_providers.dart';
import '../providers/auth_providers.dart';
import '../models/patient_model.dart';
import '../models/medication_model.dart';
import '../models/alarm_model.dart';
import '../models/slot_mapping.dart';
import '../widgets/dashboard_stats.dart';
import '../widgets/patient_card.dart';
import '../widgets/refill_page.dart';
import 'notifications_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(patientsProvider); 
    final mqttConnected = ref.watch(mqttIsConnectedProvider);
    final user = ref.watch(authStateProvider).value;
    
    final adminName = user?.displayName ?? "Admin";
    final adminUid = user?.uid ?? "";

    return patientsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text("Error: $err"))),
      data: (patients) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: _currentPage == 0 
            ? AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                title: const Text("PillPal Admin", style: TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.history, color: Colors.grey),
                    onPressed: () => Navigator.pushNamed(context, '/history'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.grey),
                    onPressed: _confirmLogout,
                  ),
                ],
              )
            : null,
          body: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              // 0. Overview
              SingleChildScrollView(
                child: Column(
                  children: [
                    if (_currentPage != 0)
                      AppBar(
                         backgroundColor: Colors.white,
                         elevation: 0,
                         title: const Text("PillPal Admin", style: TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
                      ),
                    DashboardStats(
                      patients: patients, 
                      adminName: adminName,
                      onViewRefill: () {
                        setState(() => _currentPage = 2);
                        _pageController.jumpToPage(2);
                      }
                    ),
                  ],
                ),
              ),

              // 1. Patients
              Scaffold(
                appBar: AppBar(
                  title: const Text("Patients"),
                  actions: [
                    IconButton(icon: const Icon(Icons.add), onPressed: () => _showPatientDialog(existingPatients: patients, adminName: adminName, adminUid: adminUid))
                  ]
                ),
                body: _buildPatientsPage(patients, adminName, adminUid),
              ),

              // 2. Refills
              RefillPage(patients: patients),

              // 3. Notifications
               const NotificationsScreen(),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentPage,
            onTap: (index) {
              setState(() => _currentPage = index);
              _pageController.jumpToPage(index);
            },
            type: BottomNavigationBarType.fixed,
            selectedItemColor: const Color(0xFF1565C0),
            unselectedItemColor: Colors.grey,
            showUnselectedLabels: false,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: "Overview"),
              BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: "Patients"),
              BottomNavigationBarItem(icon: Icon(Icons.inventory_2_rounded), label: "Refills"),
              BottomNavigationBarItem(icon: Icon(Icons.notifications_rounded), label: "Notifications"),
            ],
          ),
        );
      }
    );
  }

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
              ref.read(firebaseAuthProvider).signOut();
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientsPage(List<Patient> patients, String adminName, String adminUid) {
    if (patients.isEmpty) {
      return const Center(child: Text("No patients found. Tap + to add."));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: patients.length,
      itemBuilder: (context, index) {
        return PatientCard(
          patient: patients[index],
          onTap: () => _showPatientDialog(
            patientToEdit: patients[index], 
            existingPatients: patients, 
            adminName: adminName, 
            adminUid: adminUid
          ),
          onDelete: () => _confirmDelete(patients[index].id!, patients[index].name),
        );
      },
    );
  }

  void _confirmDelete(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Patient"),
        content: Text("Delete $name?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              ref.read(firestoreServiceProvider).deletePatient(id);
              Navigator.pop(ctx);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _showPatientDialog({
    Patient? patientToEdit, 
    required List<Patient> existingPatients,
    required String adminName,
    required String adminUid,
  }) async {
    final bool isEditing = patientToEdit != null;
    final firestore = ref.read(firestoreServiceProvider);
    
    int? availableNum;
    if (isEditing) {
      availableNum = patientToEdit.patientNumber;
    } else {
      availableNum = await firestore.getNextAvailablePatientNumber();
      if (availableNum == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Maximum 8 patients reached!")));
        return;
      }
    }

    final nameCtrl = TextEditingController(text: isEditing ? patientToEdit.name : '');
    final ageCtrl = TextEditingController(text: isEditing ? patientToEdit.age.toString() : '');
    String gender = isEditing ? patientToEdit.gender : "Male";
    
    List<Map<String, dynamic>> tempAlarms = [];
    if (isEditing) {
      for (var alarm in patientToEdit.alarms) {
        tempAlarms.add({
          'time': alarm.timeOfDay,
          'mealType': alarm.mealType,
          'medication': alarm.medication,
        });
      }
    }

    final formKey = GlobalKey<FormState>();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            bool isSaving = false;

            void addMealSchedule(String type) {
              String defaultTime = "08:00";
              if (type == "lunch") defaultTime = "13:00";
              if (type == "dinner") defaultTime = "19:00";

              setState(() {
                tempAlarms.add({
                  'time': defaultTime,
                  'mealType': type,
                  'medication': null,
                });
                
                final order = {'breakfast': 1, 'lunch': 2, 'dinner': 3};
                tempAlarms.sort((a, b) => (order[a['mealType']] ?? 0).compareTo(order[b['mealType']] ?? 0));
              });
            }

            void editAlarm(int alarmIndex) {
               // ... (Keep existing editAlarm logic or adapt slightly if needed)
               // For brevity, using the same logic but ensuring style matches request
               final currentMed = tempAlarms[alarmIndex]['medication'] as Medication?;
               final medNameCtrl = TextEditingController(text: currentMed?.name ?? '');
               String currentTime = tempAlarms[alarmIndex]['time'];

               showDialog(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) {
                 return AlertDialog(
                   title: Text("Edit ${tempAlarms[alarmIndex]['mealType']} Schedule"),
                   content: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(controller: medNameCtrl, decoration: const InputDecoration(labelText: "Medication Name")),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                           final parts = currentTime.split(':');
                           final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])));
                           if(t!=null) setD(() => currentTime = "${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}");
                        },
                        child: InputDecorator(decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Time"), child: Text(currentTime)),
                      )
                   ]),
                   actions: [
                     TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
                     ElevatedButton(onPressed: () {
                         setState(() {
                             tempAlarms[alarmIndex]['time'] = currentTime;
                             tempAlarms[alarmIndex]['medication'] = Medication(
                               name: medNameCtrl.text,
                               mealType: tempAlarms[alarmIndex]['mealType'],
                               slotNumber: SlotMapping.getSlotForMealType(availableNum!, tempAlarms[alarmIndex]['mealType']),
                               remainingBoxes: currentMed?.remainingBoxes ?? 3
                             );
                         });
                         Navigator.pop(c);
                     }, child: const Text("Save"))
                   ],
                 );
               }));
            }
            
            // Slots logic
            final slots = SlotMapping.getSlotsForPatient(availableNum!).join(", ");

            return AlertDialog(
              backgroundColor: const Color(0xFFF5F6F8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              contentPadding: const EdgeInsets.all(24),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? "Edit Patient $availableNum" : "Add Patient $availableNum",
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
                        ),
                        const SizedBox(height: 24),
                        
                        // Fields
                        _buildCustomField(nameCtrl, "Full Name", Icons.person),
                        const SizedBox(height: 16),
                        _buildCustomField(ageCtrl, "Age", Icons.calendar_today, isNumber: true),
                        const SizedBox(height: 16),
                        
                        // Gender
                        DropdownButtonFormField<String>(
                          value: gender,
                          decoration: InputDecoration(
                            labelText: "Gender",
                            prefixIcon: const Icon(Icons.male, color: Colors.black54),
                            border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!)),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!)),
                          ),
                          items: ["Male", "Female"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (v) => gender = v!,
                        ),
                        const SizedBox(height: 24),

                        // Patient Slot Box
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F1FC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.3))
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.badge, color: Color(0xFF1565C0)),
                              const SizedBox(width: 12),
                              Text("Patient #$availableNum", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0), fontSize: 16)),
                              const Spacer(),
                              Text("Slots: $slots", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        const Text("Medication Schedule", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (!tempAlarms.any((a) => a['mealType'] == 'breakfast'))
                               _buildMealButton("Add Breakfast", Icons.wb_sunny_outlined, const Color(0xFFFFF3E0), const Color(0xFFFFB74D), () => addMealSchedule('breakfast')),
                            if (!tempAlarms.any((a) => a['mealType'] == 'lunch'))
                               _buildMealButton("Add Lunch", Icons.cloud_outlined, const Color(0xFFE3F2FD), const Color(0xFF64B5F6), () => addMealSchedule('lunch')),
                          ],
                        ),
                        const SizedBox(height: 10),
                         if (!tempAlarms.any((a) => a['mealType'] == 'dinner'))
                               _buildMealButton("Add Dinner", Icons.nightlight_round, const Color(0xFFF3E5F5), const Color(0xFFBA68C8), () => addMealSchedule('dinner')),

                        const SizedBox(height: 20),
                        
                        if (tempAlarms.isEmpty)
                          const Center(child: Padding(padding: EdgeInsets.all(10), child: Text("No schedules added yet.", style: TextStyle(color: Colors.black38, fontStyle: FontStyle.italic)))),

                        ...tempAlarms.asMap().entries.map((entry) {
                           int index = entry.key;
                           var alarm = entry.value;
                           Color bg = Colors.white;
                           IconData icon = Icons.access_time;
                           if (alarm['mealType'] == 'breakfast') { bg = const Color(0xFFFFF3E0); icon = Icons.wb_sunny; }
                           if (alarm['mealType'] == 'lunch') { bg = const Color(0xFFE3F2FD); icon = Icons.cloud; }
                           if (alarm['mealType'] == 'dinner') { bg = const Color(0xFFF3E5F5); icon = Icons.nightlight_round; }

                           return Container(
                             margin: const EdgeInsets.only(bottom: 8),
                             decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                             child: ListTile(
                               leading: Icon(icon, color: Colors.black54),
                               title: Text("${alarm['mealType'].toString().toUpperCase()} - ${alarm['time']}"),
                               subtitle: Text(alarm['medication']?.name ?? "No Medication"),
                               trailing: IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => editAlarm(index)),
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
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  onPressed: isSaving ? null : () async {
                    if (formKey.currentState!.validate()) {
                       setState(() => isSaving = true);
                       List<AlarmModel> finalAlarms = tempAlarms.map((a) => AlarmModel(
                         timeOfDay: a['time'],
                         mealType: a['mealType'],
                         isActive: true,
                         medication: a['medication']
                       )).toList();

                       try {
                         if (isEditing) {
                           await firestore.updatePatient(patientToEdit!, nameCtrl.text, int.parse(ageCtrl.text), gender, finalAlarms);
                         } else {
                           await firestore.addPatient(nameCtrl.text, int.parse(ageCtrl.text), availableNum!, gender, adminName, adminUid, finalAlarms);
                         }
                         if(mounted) Navigator.pop(ctx);
                       } catch (e) {
                         setState(() => isSaving = false);
                       }
                    }
                  },
                  child: Text(isEditing ? "Update" : "Save", style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCustomField(TextEditingController controller, String label, IconData icon, {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      validator: (v) => v!.isEmpty ? "Required" : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.black54),
        border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!)),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF1565C0))),
      ),
    );
  }

  Widget _buildMealButton(String label, IconData icon, Color bg, Color accent, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withOpacity(0.3))
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}
