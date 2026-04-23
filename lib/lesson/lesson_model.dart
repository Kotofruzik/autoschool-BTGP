import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class Lesson {
  String? objectId;
  String type;
  DateTime startTime;
  DateTime endTime;
  int? duration;
  String? carBrand;
  String? carModel;
  String? carNumber;
  String? carPhotoUrl;
  String? comment;
  ParseUser? student;
  ParseUser? instructor;
  String status; // scheduled, ongoing, completed, cancelled

  Lesson({
    this.objectId,
    required this.type,
    required this.startTime,
    required this.endTime,
    this.duration,
    this.carBrand,
    this.carModel,
    this.carNumber,
    this.carPhotoUrl,
    this.comment,
    this.student,
    this.instructor,
    required this.status,
  });

  factory Lesson.fromParse(ParseObject obj) {
    final utcStart = obj.get<DateTime>('startTime') ?? DateTime.now().toUtc();
    final utcEnd = obj.get<DateTime>('endTime') ?? DateTime.now().add(const Duration(hours: 1)).toUtc();
    
    // Получаем студента с правильной обработкой типа
    ParseUser? student;
    final studentData = obj.get('student');
    if (studentData is ParseUser) {
      student = studentData;
    } else if (studentData is Map<String, dynamic>) {
      student = ParseUser(null, null, null);
      student.objectId = studentData['objectId'] as String?;
      student.set('username', studentData['username']);
      student.set('email', studentData['email']);
    }

    // Получаем инструктора с правильной обработкой типа
    ParseUser? instructor;
    final instructorData = obj.get('instructor');
    if (instructorData is ParseUser) {
      instructor = instructorData;
    } else if (instructorData is Map<String, dynamic>) {
      instructor = ParseUser(null, null, null);
      instructor.objectId = instructorData['objectId'] as String?;
      instructor.set('username', instructorData['username']);
      instructor.set('email', instructorData['email']);
    }

    return Lesson(
      objectId: obj.objectId,
      type: obj.get<String>('type') ?? 'driving',
      startTime: utcStart.toLocal(),
      endTime: utcEnd.toLocal(),
      duration: obj.get<int>('duration'),
      carBrand: obj.get<String>('carBrand'),
      carModel: obj.get<String>('carModel'),
      carNumber: obj.get<String>('carNumber'),
      carPhotoUrl: obj.get<String>('carPhoto'),
      comment: obj.get<String>('comment'),
      student: student,
      instructor: instructor,
      status: obj.get<String>('status') ?? 'scheduled',
    );
  }

  ParseObject toParse() {
    final obj = ParseObject('Lesson')
      ..objectId = objectId
      ..set('type', type)
      ..set('startTime', startTime.toUtc())
      ..set('endTime', endTime.toUtc())
      ..set('duration', duration)
      ..set('carBrand', carBrand)
      ..set('carModel', carModel)
      ..set('carNumber', carNumber)
      ..set('carPhoto', carPhotoUrl)
      ..set('comment', comment)
      ..set('student', student?.toPointer())
      ..set('instructor', instructor?.toPointer())
      ..set('status', status);
    return obj;
  }

  String get displayType => type == 'driving' ? 'Вождение' : 'Экзамен';
  String get displayStartDate => '${startTime.day}.${startTime.month}.${startTime.year}';
  String get displayStartTime => '${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}';
  String get displayEndTime => '${endTime.hour}:${endTime.minute.toString().padLeft(2, '0')}';
  String get displayDateTimeRange => '$displayStartDate $displayStartTime – $displayEndTime';
  String get displayStatus {
    switch (status) {
      case 'scheduled':
        return 'Запланировано';
      case 'ongoing':
        return 'Идёт сейчас';
      case 'completed':
        return 'Проведено';
      case 'cancelled':
        return 'Отменено';
      default:
        return status;
    }
  }

  int get calculatedDuration => endTime.difference(startTime).inMinutes;
  bool get isOngoing {
    final now = DateTime.now();
    return startTime.isBefore(now) && endTime.isAfter(now);
  }
  bool get isPast => endTime.isBefore(DateTime.now());

  Duration get timeUntilStart => startTime.difference(DateTime.now());
  Duration get timeUntilEnd => endTime.difference(DateTime.now());

  // Форматированный обратный отсчёт с секундами
  String get countdownDetailed {
    final until = timeUntilStart;
    if (until.isNegative) {
      if (isOngoing) {
        final left = timeUntilEnd;
        if (left.inDays > 0) {
          return 'Осталось: ${left.inDays}д ${left.inHours.remainder(24)}ч ${left.inMinutes.remainder(60)}м ${left.inSeconds.remainder(60)}с';
        } else if (left.inHours > 0) {
          return 'Осталось: ${left.inHours}ч ${left.inMinutes.remainder(60)}м ${left.inSeconds.remainder(60)}с';
        } else if (left.inMinutes > 0) {
          return 'Осталось: ${left.inMinutes}м ${left.inSeconds.remainder(60)}с';
        } else {
          return 'Осталось: ${left.inSeconds}с';
        }
      } else {
        return 'Завершено';
      }
    }
    if (until.inDays > 0) {
      return 'До начала: ${until.inDays}д ${until.inHours.remainder(24)}ч ${until.inMinutes.remainder(60)}м ${until.inSeconds.remainder(60)}с';
    } else if (until.inHours > 0) {
      return 'До начала: ${until.inHours}ч ${until.inMinutes.remainder(60)}м ${until.inSeconds.remainder(60)}с';
    } else if (until.inMinutes > 0) {
      return 'До начала: ${until.inMinutes}м ${until.inSeconds.remainder(60)}с';
    } else {
      return 'До начала: ${until.inSeconds}с';
    }
  }

  // Краткий формат без секунд (для списка)
  String get countdownShort {
    final until = timeUntilStart;
    if (until.isNegative) {
      if (isOngoing) {
        final left = timeUntilEnd;
        if (left.inDays > 0) return 'Осталось: ${left.inDays}д ${left.inHours.remainder(24)}ч';
        if (left.inHours > 0) return 'Осталось: ${left.inHours}ч ${left.inMinutes.remainder(60)}м';
        if (left.inMinutes > 0) return 'Осталось: ${left.inMinutes}м';
        return 'Осталось: ${left.inSeconds}с';
      } else {
        return 'Завершено';
      }
    }
    if (until.inDays > 0) return 'До: ${until.inDays}д ${until.inHours.remainder(24)}ч';
    if (until.inHours > 0) return 'До: ${until.inHours}ч ${until.inMinutes.remainder(60)}м';
    if (until.inMinutes > 0) return 'До: ${until.inMinutes}м';
    return 'До: ${until.inSeconds}с';
  }
}
