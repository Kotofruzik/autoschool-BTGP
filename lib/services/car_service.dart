import 'dart:io';
import 'package:minio/io.dart';
import 'package:minio/minio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../models/car_model.dart';

class CarService {
  static const String _serverUrl = 'https://parseapi.back4app.com';
  static const String _appId = 'qCxbZic6eqme0pvScG5jLoCxDUxztB9FGuiXhEiy';
  static const String _clientKey = '50yEotCNReUkwSd7nhVmhYnoZspmLcbizp1GJC3v';

  Future<String?> uploadCarPhoto(XFile image) async {
    try {
      final file = File(image.path);
      const accessKey = 'YCAJEyTjVJ5hPHjDHwCdRFvqu';
      const secretKey = 'YCPsjstQHgXYSe0ZwRRl-fKFUCSnKMAj5WtyGJ4W';
      const bucket = 'autoschoolbtgp';
      const region = 'ru-central1';
      const endpoint = 'storage.yandexcloud.net';

      final minio = Minio(
        endPoint: endpoint,
        port: 443,
        useSSL: true,
        accessKey: accessKey,
        secretKey: secretKey,
        region: region,
      );

      final key = 'cars/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await minio.fPutObject(
        bucket,
        key,
        file.path,
        metadata: {'Content-Type': 'image/jpeg'},
      );

      final photoUrl = 'https://$endpoint/$bucket/$key';
      return photoUrl;
    } catch (e) {
      print('❌ Ошибка загрузки фото автомобиля: $e');
      return null;
    }
  }

  Future<Car?> createCar({
    required String brand,
    required String model,
    required String number,
    String? color,
    String? transmission,
    String? photoUrl,
    required ParseUser instructor,
  }) async {
    final car = ParseObject('Car')
      ..set('brand', brand)
      ..set('model', model)
      ..set('number', number)
      ..set('color', color)
      ..set('transmission', transmission)
      ..set('photoUrl', photoUrl)
      ..set('instructor', instructor.toPointer())
      ..set('isActive', true)
      ..set('createdAt', DateTime.now().toUtc());

    final response = await car.save();

    if (response.success) {
      final createdCar = response.result as ParseObject;
      print('✅ Автомобиль создан: ${createdCar.objectId}');
      return Car.fromParse(createdCar);
    } else {
      throw Exception(response.error!.message);
    }
  }

  Future<List<Car>> getCarsForInstructor(ParseUser instructor) async {
    final query = QueryBuilder<ParseObject>(ParseObject('Car'))
      ..whereEqualTo('instructor', instructor.toPointer())
      ..orderByDescending('createdAt');

    final response = await query.query();
    if (response.success && response.results != null) {
      return response.results!.map((obj) => Car.fromParse(obj as ParseObject)).toList();
    } else {
      print('⚠️ Ошибка получения автомобилей: ${response.error?.message}');
      return [];
    }
  }

  Future<Car?> updateCar(Car car) async {
    final parseObj = car.toParse();
    final response = await parseObj.save();

    if (response.success) {
      final updated = response.result as ParseObject;
      return Car.fromParse(updated);
    } else {
      throw Exception(response.error?.message);
    }
  }

  Future<void> deleteCar(String carId) async {
    final car = ParseObject('Car')..objectId = carId;
    final response = await car.delete();
    if (!response.success) {
      throw Exception(response.error?.message ?? 'Не удалось удалить автомобиль');
    }
  }

  Future<void> deactivateCar(String carId) async {
    final query = QueryBuilder<ParseObject>(ParseObject('Car'))
      ..whereEqualTo('objectId', carId);
    final response = await query.query();
    
    if (response.success && response.results != null && response.results!.isNotEmpty) {
      final car = response.results!.first as ParseObject;
      car.set('isActive', false);
      final saveResponse = await car.save();
      if (!saveResponse.success) {
        throw Exception(saveResponse.error?.message ?? 'Не удалось деактивировать автомобиль');
      }
    }
  }

  Future<Car?> getCarById(String carId) async {
    final query = QueryBuilder<ParseObject>(ParseObject('Car'))
      ..whereEqualTo('objectId', carId);
    
    final response = await query.query();
    if (response.success && response.results != null && response.results!.isNotEmpty) {
      return Car.fromParse(response.results!.first as ParseObject);
    }
    return null;
  }
}
