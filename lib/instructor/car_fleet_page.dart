import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/car_service.dart';
import '../models/car_model.dart';
import '../services/auth_service.dart';

class CarFleetPage extends StatefulWidget {
  const CarFleetPage({Key? key}) : super(key: key);

  @override
  _CarFleetPageState createState() => _CarFleetPageState();
}

class _CarFleetPageState extends State<CarFleetPage> {
  final CarService _carService = CarService();
  List<Car> _cars = [];
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadCars();
  }

  Future<void> _loadCars() async {
    setState(() => _isLoading = true);
    final instructor = Provider.of<AuthService>(context, listen: false).currentUser;
    if (instructor == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final cars = await _carService.getCarsForInstructor(instructor);
      setState(() {
        _cars = cars.where((c) => c.isActive).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Ошибка загрузки автомобилей: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToCarForm({Car? car}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CarFormPage(car: car)),
    );

    if (result == true) {
      _loadCars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(car == null ? 'Автомобиль добавлен' : 'Автомобиль обновлён'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteCar(Car car) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удаление автомобиля'),
        content: Text('Вы уверены, что хотите удалить автомобиль ${car.fullName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _carService.deleteCar(car.objectId!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Автомобиль удалён'), backgroundColor: Colors.green),
        );
        _loadCars();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Автопарк'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.lightBlueAccent],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _cars.isEmpty
                ? _buildEmptyState()
                : _buildCarList(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToCarForm(),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue,
        icon: const Icon(Icons.add),
        label: const Text('Добавить авто'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_car, size: 80, color: Colors.white.withOpacity(0.5)),
          const SizedBox(height: 24),
          const Text(
            'У вас пока нет автомобилей',
            style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Добавьте первый автомобиль для записи на вождения',
            style: TextStyle(fontSize: 14, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _navigateToCarForm(),
            icon: const Icon(Icons.add),
            label: const Text('Добавить автомобиль'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarList() {
    return RefreshIndicator(
      onRefresh: _loadCars,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _cars.length,
        itemBuilder: (context, index) {
          final car = _cars[index];
          return _buildCarCard(car);
        },
      ),
    );
  }

  Widget _buildCarCard(Car car) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _navigateToCarForm(car: car),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (car.photoUrl != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: car.photoUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey.shade300,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.directions_car, size: 40, color: Colors.grey),
                  ),
                ),
              )
            else
              Container(
                height: 120,
                color: Colors.blue.shade100,
                child: const Center(
                  child: Icon(Icons.directions_car, size: 60, color: Colors.blue),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    car.fullName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.confirmation_number, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        car.number,
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.settings, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        car.transmissionLabel,
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  if (car.color != null && car.color!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.palette, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          car.color!,
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _navigateToCarForm(car: car),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Редактировать'),
                        style: TextButton.styleFrom(foregroundColor: Colors.blue),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _deleteCar(car),
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('Удалить'),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Страница добавления/редактирования автомобиля
class CarFormPage extends StatefulWidget {
  final Car? car;

  const CarFormPage({Key? key, this.car}) : super(key: key);

  @override
  _CarFormPageState createState() => _CarFormPageState();
}

class _CarFormPageState extends State<CarFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _numberController = TextEditingController();
  String? _color;
  String? _transmission;
  String? _photoUrl;
  bool _isSaving = false;
  final CarService _carService = CarService();
  final ImagePicker _picker = ImagePicker();

  final List<String> _colors = [
    'Белый', 'Чёрный', 'Серый', 'Серебристый', 'Красный',
    'Синий', 'Зелёный', 'Жёлтый', 'Оранжевый', 'Коричневый',
    'Бежевый', 'Голубой', 'Фиолетовый', 'Другой'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.car != null) {
      _brandController.text = widget.car!.brand;
      _modelController.text = widget.car!.model;
      _numberController.text = widget.car!.number;
      _color = widget.car!.color;
      _transmission = widget.car!.transmission;
      _photoUrl = widget.car!.photoUrl;
    }
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
      compressQuality: 80,
      maxWidth: 1024,
      maxHeight: 576,
    );

    final fileToUpload = croppedFile != null ? File(croppedFile.path) : File(image.path);
    setState(() => _isSaving = true);

    final photoUrl = await _carService.uploadCarPhoto(XFile(fileToUpload.path));
    setState(() {
      _photoUrl = photoUrl;
      _isSaving = false;
    });

    if (photoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка загрузки фото'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _saveCar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final instructor = Provider.of<AuthService>(context, listen: false).currentUser;

    if (instructor == null) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка авторизации'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      if (widget.car == null) {
        // Создание нового автомобиля
        await _carService.createCar(
          brand: _brandController.text.trim(),
          model: _modelController.text.trim(),
          number: _numberController.text.trim().toUpperCase(),
          color: _color,
          transmission: _transmission,
          photoUrl: _photoUrl,
          instructor: instructor,
        );
      } else {
        // Обновление существующего
        final updatedCar = Car(
          objectId: widget.car!.objectId,
          brand: _brandController.text.trim(),
          model: _modelController.text.trim(),
          number: _numberController.text.trim().toUpperCase(),
          color: _color,
          transmission: _transmission,
          photoUrl: _photoUrl,
          instructor: instructor,
        );
        await _carService.updateCar(updatedCar);
      }

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.car != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Редактировать автомобиль' : 'Добавить автомобиль'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.lightBlueAccent],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Фото автомобиля
                  GestureDetector(
                    onTap: _pickAndUploadImage,
                    child: Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: _photoUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: _photoUrl!,
                                    fit: BoxFit.cover,
                                  ),
                                  Positioned(
                                    right: 8,
                                    bottom: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.8),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, size: 50, color: Colors.white.withOpacity(0.7)),
                                const SizedBox(height: 8),
                                Text(
                                  'Добавить фото',
                                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                                ),
                              ],
                            ),
                    ),
                  ),
                  if (_isSaving)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(),
                    ),
                  const SizedBox(height: 24),

                  // Марка
                  TextFormField(
                    controller: _brandController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Марка *',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.local_car_wash, color: Colors.white70),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Введите марку автомобиля';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Модель
                  TextFormField(
                    controller: _modelController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Модель *',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.settings, color: Colors.white70),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Введите модель автомобиля';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Госномер
                  TextFormField(
                    controller: _numberController,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Госномер *',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.confirmation_number, color: Colors.white70),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Введите госномер';
                      }
                      if (value.trim().length < 5) {
                        return 'Госномер должен быть не менее 5 символов';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Цвет
                  DropdownButtonFormField<String>(
                    value: _color,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Цвет (необязательно)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.palette, color: Colors.white70),
                    ),
                    items: _colors.map((color) => DropdownMenuItem(value: color, child: Text(color))).toList(),
                    onChanged: (value) => setState(() => _color = value),
                  ),
                  const SizedBox(height: 16),

                  // Трансмиссия
                  DropdownButtonFormField<String>(
                    value: _transmission,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Трансмиссия (необязательно)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.settings_suggest, color: Colors.white70),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'automatic', child: Text('Автомат')),
                      DropdownMenuItem(value: 'manual', child: Text('Механика')),
                    ],
                    onChanged: (value) => setState(() => _transmission = value),
                  ),
                  const SizedBox(height: 32),

                  // Кнопка сохранения
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveCar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(
                            isEdit ? 'Сохранить изменения' : 'Добавить автомобиль',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
