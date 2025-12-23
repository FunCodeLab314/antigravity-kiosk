
import '../utils/enums.dart';

class SlotMapping {
  static const Map<int, List<int>> patientSlots = {
    1: [1, 5, 9],    // Patient 1: Breakfast(1), Lunch(5), Dinner(9)
    2: [2, 6, 10],
    3: [3, 7, 11],
    4: [4, 8, 12],
    5: [13, 17, 21],
    6: [14, 18, 22],
    7: [15, 19, 23],
    8: [16, 20, 24],
  };

  static List<int> getSlotsForPatient(int patientNum) {
    return patientSlots[patientNum] ?? [];
  }

  static int getSlotForMealType(int patientNum, String mealType) {
    // Try to parse the string to enum, fallback to default logic
    MealType type;
    try {
      type = MealType.values.byName(mealType.toLowerCase());
    } catch (_) {
      type = MealType.breakfast;
    }
    
    final slots = getSlotsForPatient(patientNum);
    if (slots.isEmpty) return 0; // Should handle error better, but consistent with old logic

    switch (type) {
      case MealType.breakfast: return slots[0];
      case MealType.lunch: return slots[1];
      case MealType.dinner: return slots[2];
    }
  }
}
