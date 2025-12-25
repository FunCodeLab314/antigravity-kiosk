import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:intl/intl.dart';
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
  Timer? _clockTimer;
  String _currentTime = '';
  String _currentDate = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime = DateFormat('HH:mm:ss').format(now);
      _currentDate = DateFormat('EEEE, MMMM d, yyyy').format(now);
    });
  }

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(patientsProvider); 
    final user = ref.watch(authStateProvider).value;
    
    final adminName = user?.displayName ?? "Admin";
    final adminUid = user?.uid ?? "";

    return patientsAsync.when(
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1565C0)),
          )
        )
      ),
      error: (err, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text("Error: $err", style: const TextStyle(color: Colors.red)),
            ],
          )
        )
      ),
      data: (patients) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          body: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            children: [
              // 0. Overview with Clock
              _buildOverviewPage(patients, adminName, adminUid),

              // 1. Patients
              _buildPatientsPageWrapper(patients, adminName, adminUid),

              // 2. Refills
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF5F7FA), Colors.white],
                  ),
                ),
                child: RefillPage(patients: patients),
              ),

              // 3. Notifications
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF5F7FA), Colors.white],
                  ),
                ),
                child: const NotificationsScreen(),
              ),
            ],
          ),
          bottomNavigationBar: _buildModernBottomNav(),
        );
      }
    );
  }

  Widget _buildOverviewPage(List<Patient> patients, String adminName, String adminUid) {
  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFE3F2FD),
          Color(0xFFF5F7FA),
          Colors.white,
        ],
      ),
    ),
    child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          children: [
            // Compact Header with Clock
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1565C0), Color(0xFF1976D2), Color(0xFF42A5F5)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1565C0).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "PillPal Kiosk",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Row(
                        children: [
                          _buildHeaderIconButton(
                            Icons.history_rounded,
                            () => Navigator.pushNamed(context, '/history'),
                          ),
                          const SizedBox(width: 8),
                          _buildHeaderIconButton(
                            Icons.logout_rounded,
                            _confirmLogout,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Compact Digital Clock
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _currentTime,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentDate,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Slim Welcome Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Welcome back, $adminName",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${patients.length}/8",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Dashboard Stats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DashboardStats(
                patients: patients,
                adminName: adminName,
                onViewRefill: () {
                  _pageController.animateToPage(
                    2,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildHeaderIconButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
        tooltip: icon == Icons.history_rounded ? 'History' : 'Logout',
      ),
    );
  }

  Widget _buildPatientsPageWrapper(List<Patient> patients, String adminName, String adminUid) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF5F7FA), Colors.white],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.people_alt_rounded,
                      color: Color(0xFF1565C0),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Patients",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                        Text(
                          "Manage patient information",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1565C0).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showPatientDialog(
                          existingPatients: patients,
                          adminName: adminName,
                          adminUid: adminUid,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Row(
                            children: [
                              Icon(Icons.add, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                "Add",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Patients List
            Expanded(
              child: _buildPatientsPage(patients, adminName, adminUid),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientsPage(List<Patient> patients, String adminName, String adminUid) {
    if (patients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline,
                size: 64,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "No patients yet",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Tap the + button to add a patient",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: patients.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: PatientCard(
            patient: patients[index],
            onTap: () => _showPatientDialog(
              patientToEdit: patients[index],
              existingPatients: patients,
              adminName: adminName,
              adminUid: adminUid,
            ),
            onDelete: () => _confirmDelete(patients[index].id!, patients[index].name),
          ),
        );
      },
    );
  }

  Widget _buildModernBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.grid_view_rounded, "Overview"),
              _buildNavItem(1, Icons.people_alt_rounded, "Patients"),
              _buildNavItem(2, Icons.inventory_2_rounded, "Refills"),
              _buildNavItem(3, Icons.notifications_rounded, "Alerts"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isActive = _currentPage == index;
    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 20 : 12,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                )
              : null,
          color: isActive ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : Colors.grey,
              size: 24,
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.logout_rounded, color: Colors.red),
            ),
            const SizedBox(width: 12),
            const Text("Logout"),
          ],
        ),
        content: const Text("Are you sure you want to exit the kiosk system?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(firebaseAuthProvider).signOut();
            },
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_rounded, color: Colors.red),
            ),
            const SizedBox(width: 12),
            const Text("Delete Patient"),
          ],
        ),
        content: Text("Are you sure you want to delete $name?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Maximum 8 patients reached!"))
          );
        }
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
          'id': alarm.id,
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
                  'id': null,
                  'time': defaultTime,
                  'mealType': type,
                  'medication': null,
                });

                final order = {'breakfast': 1, 'lunch': 2, 'dinner': 3};
                tempAlarms.sort((a, b) => (order[a['mealType']] ?? 0).compareTo(order[b['mealType']] ?? 0));
              });
            }

            void editAlarm(int alarmIndex) {
              final currentMed = tempAlarms[alarmIndex]['medication'] as Medication?;
              final medNameCtrl = TextEditingController(text: currentMed?.name ?? '');
              String currentTime = tempAlarms[alarmIndex]['time'];

              showDialog(
                context: context,
                builder: (c) => StatefulBuilder(
                  builder: (c, setD) {
                    return AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Text("Edit ${tempAlarms[alarmIndex]['mealType']} Schedule"),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: medNameCtrl,
                            decoration: const InputDecoration(
                              labelText: "Medication Name",
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: () async {
                              final parts = currentTime.split(':');
                              final t = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay(
                                  hour: int.parse(parts[0]),
                                  minute: int.parse(parts[1]),
                                ),
                              );
                              if (t != null) {
                                setD(() => currentTime = "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}");
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: "Time",
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(currentTime),
                                  const Icon(Icons.access_time),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text("Cancel"),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              tempAlarms[alarmIndex]['time'] = currentTime;
                              tempAlarms[alarmIndex]['medication'] = Medication(
                                name: medNameCtrl.text,
                                mealType: tempAlarms[alarmIndex]['mealType'],
                                slotNumber: SlotMapping.getSlotForMealType(
                                  availableNum!,
                                  tempAlarms[alarmIndex]['mealType'],
                                ),
                                remainingBoxes: currentMed?.remainingBoxes ?? 3,
                              );
                            });
                            Navigator.pop(c);
                          },
                          child: const Text("Save"),
                        ),
                      ],
                    );
                  },
                ),
              );
            }

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
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.person_add_rounded,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isEditing ? "Edit Patient $availableNum" : "Add Patient $availableNum",
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1565C0),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        _buildCustomField(nameCtrl, "Full Name", Icons.person),
                        const SizedBox(height: 16),
                        _buildCustomField(ageCtrl, "Age", Icons.calendar_today, isNumber: true),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<String>(
                          value: gender,
                          decoration: InputDecoration(
                            labelText: "Gender",
                            prefixIcon: const Icon(Icons.male, color: Colors.black54),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                          items: ["Male", "Female"]
                              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (v) => gender = v!,
                        ),
                        const SizedBox(height: 24),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF1565C0).withOpacity(0.1),
                                const Color(0xFF42A5F5).withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF1565C0).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.badge, color: Color(0xFF1565C0)),
                              const SizedBox(width: 12),
                              Text(
                                "Patient #$availableNum",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1565C0),
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                "Slots: $slots",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        const Text(
                          "Medication Schedule",
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!tempAlarms.any((a) => a['mealType'] == 'breakfast'))
                              _buildMealButton(
                                "Add Breakfast",
                                Icons.wb_sunny_outlined,
                                const Color(0xFFFFF3E0),
                                const Color(0xFFFFB74D),
                                () => addMealSchedule('breakfast'),
                              ),
                            if (!tempAlarms.any((a) => a['mealType'] == 'lunch'))
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: _buildMealButton(
                                  "Add Lunch",
                                  Icons.cloud_outlined,
                                  const Color(0xFFE3F2FD),
                                  const Color(0xFF64B5F6),
                                  () => addMealSchedule('lunch'),
                                ),
                              ),
                            if (!tempAlarms.any((a) => a['mealType'] == 'dinner'))
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: _buildMealButton(
                                  "Add Dinner",
                                  Icons.nightlight_round,
                                  const Color(0xFFF3E5F5),
                                  const Color(0xFFBA68C8),
                                  () => addMealSchedule('dinner'),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        if (tempAlarms.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(10),
                              child: Text(
                                "No schedules added yet.",
                                style: TextStyle(
                                  color: Colors.black38,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ),

                        ...tempAlarms.asMap().entries.map((entry) {
                          int index = entry.key;
                          var alarm = entry.value;
                          Color bg = Colors.white;
                          IconData icon = Icons.access_time;
                          if (alarm['mealType'] == 'breakfast') {
                            bg = const Color(0xFFFFF3E0);
                            icon = Icons.wb_sunny;
                          }
                          if (alarm['mealType'] == 'lunch') {
                            bg = const Color(0xFFE3F2FD);
                            icon = Icons.cloud;
                          }
                          if (alarm['mealType'] == 'dinner') {
                            bg = const Color(0xFFF3E5F5);
                            icon = Icons.nightlight_round;
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(icon, color: Colors.black87, size: 24),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            alarm['mealType'].toString().toUpperCase(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            alarm['time'],
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  alarm['medication']?.name ?? "No Medication",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                    fontStyle: alarm['medication'] == null
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      icon: const Icon(Icons.edit, size: 18),
                                      label: const Text("Edit"),
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xFF1565C0),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                      onPressed: () => editAlarm(index),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      icon: const Icon(Icons.delete, size: 18),
                                      label: const Text("Delete"),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                      onPressed: () =>
                                          setState(() => tempAlarms.removeAt(index)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setState(() => isSaving = true);

                            List<AlarmModel> finalAlarms = tempAlarms
                                .map((a) => AlarmModel(
                                      id: a['id'],
                                      timeOfDay: a['time'],
                                      mealType: a['mealType'],
                                      isActive: true,
                                      medication: a['medication'],
                                    ))
                                .toList();

                            try {
                              if (isEditing) {
                                await firestore.updatePatient(
                                  patientToEdit!,
                                  nameCtrl.text,
                                  int.parse(ageCtrl.text),
                                  gender,
                                  finalAlarms,
                                );
                              } else {
                                await firestore.addPatient(
                                  nameCtrl.text,
                                  int.parse(ageCtrl.text),
                                  availableNum!,
                                  gender,
                                  adminName,
                                  adminUid,
                                  finalAlarms,
                                );
                              }
                              if (mounted) Navigator.pop(ctx);
                            } catch (e) {
                              setState(() => isSaving = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Error: $e")),
                                );
                              }
                            }
                          }
                        },
                  child: Text(
                    isEditing ? "Update" : "Save",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCustomField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNumber = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      validator: (v) => v!.isEmpty ? "Required" : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.black54),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1565C0)),
        ),
      ),
    );
  }

  Widget _buildMealButton(
    String label,
    IconData icon,
    Color bg,
    Color accent,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: accent),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}