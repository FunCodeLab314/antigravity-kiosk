
import 'medication_model.dart';

class AlarmModel {
  String? id;
  String timeOfDay;
  String mealType; // 'breakfast', 'lunch', 'dinner'
  bool isActive;
  Medication medication;

  AlarmModel({
    this.id,
    required this.timeOfDay,
    required this.mealType,
    this.isActive = true,
    required this.medication,
  });

  factory AlarmModel.fromMap(
    Map<String, dynamic> data,
    String id,
    Medication med,
  ) {
    return AlarmModel(
      id: id,
      timeOfDay: data['timeOfDay'] ?? "00:00",
      mealType: data['mealType'] ?? 'breakfast',
      isActive: data['isActive'] ?? true,
      medication: med,
    );
  }

  int get hour => int.parse(timeOfDay.split(':')[0]);
  int get minute => int.parse(timeOfDay.split(':')[1]);
}
