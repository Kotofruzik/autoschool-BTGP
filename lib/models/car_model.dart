import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class Car {
  String? objectId;
  String brand;
  String model;
  String number;
  String? color;
  String? transmission; // manual, automatic
  String? photoUrl;
  ParseUser? instructor;
  bool isActive;
  DateTime? createdAt;

  Car({
    this.objectId,
    required this.brand,
    required this.model,
    required this.number,
    this.color,
    this.transmission,
    this.photoUrl,
    this.instructor,
    this.isActive = true,
    this.createdAt,
  });

  factory Car.fromParse(ParseObject obj) {
    // Получаем инструктора с правильной обработкой типа
    ParseUser? instructor;
    final instructorData = obj.get('instructor');
    if (instructorData is ParseUser) {
      instructor = instructorData;
    } else if (instructorData is Map<String, dynamic>) {
      // Если данные пришли в виде карты, создаём ParseUser из них
      instructor = ParseUser(null, null, null);
      instructor.objectId = instructorData['objectId'] as String?;
      // Копируем остальные поля если они есть
      instructor.set('username', instructorData['username']);
      instructor.set('email', instructorData['email']);
    }

    return Car(
      objectId: obj.objectId,
      brand: obj.get<String>('brand') ?? '',
      model: obj.get<String>('model') ?? '',
      number: obj.get<String>('number') ?? '',
      color: obj.get<String>('color'),
      transmission: obj.get<String>('transmission'),
      photoUrl: obj.get<String>('photoUrl'),
      instructor: instructor,
      isActive: obj.get<bool>('isActive') ?? true,
      createdAt: obj.get<DateTime>('createdAt'),
    );
  }

  ParseObject toParse() {
    final obj = ParseObject('Car')
      ..objectId = objectId
      ..set('brand', brand)
      ..set('model', model)
      ..set('number', number)
      ..set('color', color)
      ..set('transmission', transmission)
      ..set('photoUrl', photoUrl)
      ..set('instructor', instructor?.toPointer())
      ..set('isActive', isActive)
      ..set('createdAt', createdAt ?? DateTime.now().toUtc());
    return obj;
  }

  String get fullName => '$brand $model';
  
  String get transmissionLabel {
    if (transmission == null) return 'Не указана';
    return transmission == 'automatic' ? 'Автомат' : 'Механика';
  }
}
