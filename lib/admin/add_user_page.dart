import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';
import 'package:autoschool_btgp/services/users_provider.dart';
import 'package:cross_file/cross_file.dart';

class AddUserPage extends StatefulWidget {
  @override
  _AddUserPageState createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _surnameController = TextEditingController();
  final _firstnameController = TextEditingController();
  final _patronymicController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedRole = 'student';
  bool _isLoading = false;

  CroppedFile? _newCroppedImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAndCropImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 80,
      maxWidth: 512,
      maxHeight: 512,
    );

    if (croppedFile != null) {
      setState(() {
        _newCroppedImage = croppedFile;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _surnameController.dispose();
    _firstnameController.dispose();
    _patronymicController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final provider = Provider.of<UsersProvider>(context, listen: false);

    try {
      final newUser = await provider.createUserAndReturn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        surname: _surnameController.text.trim(),
        firstname: _firstnameController.text.trim(),
        patronymic: _patronymicController.text.trim(),
        phone: _phoneController.text.trim(),
        role: _selectedRole,
      );

      if (newUser != null) {
        if (_newCroppedImage != null) {
          final xFile = XFile(_newCroppedImage!.path);
          final photoUrl = await provider.uploadPhotoForUser(newUser.objectId!, xFile);
          if (photoUrl != null) {
            newUser.set('photo', photoUrl);
            await newUser.save();
            provider.updateUserLocally(newUser);
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пользователь создан'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error ?? 'Ошибка создания'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Добавить пользователя'),
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
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickAndCropImage,
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                            image: _newCroppedImage != null
                                ? DecorationImage(
                              image: FileImage(File(_newCroppedImage!.path)),
                              fit: BoxFit.cover,
                            )
                                : null,
                          ),
                          child: _newCroppedImage == null
                              ? const Icon(Icons.person, size: 50, color: Colors.blue)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt,
                                color: Colors.blue, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _surnameController,
                          decoration: const InputDecoration(
                            labelText: 'Фамилия *',
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (v) => v?.isEmpty ?? true ? 'Обязательное поле' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _firstnameController,
                          decoration: const InputDecoration(
                            labelText: 'Имя *',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) => v?.isEmpty ?? true ? 'Обязательное поле' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _patronymicController,
                          decoration: const InputDecoration(
                            labelText: 'Отчество',
                            prefixIcon: Icon(Icons.person),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email *',
                            prefixIcon: Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v?.isEmpty ?? true) return 'Обязательное поле';
                            if (!v!.contains('@')) return 'Некорректный email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Пароль *',
                            prefixIcon: Icon(Icons.lock),
                          ),
                          obscureText: true,
                          validator: (v) => v?.isEmpty ?? true ? 'Обязательное поле' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Телефон *',
                            prefixIcon: Icon(Icons.phone),
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (v) => v?.isEmpty ?? true ? 'Обязательное поле' : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedRole,
                          items: const [
                            DropdownMenuItem(value: 'student', child: Text('Ученик')),
                            DropdownMenuItem(value: 'instructor', child: Text('Инструктор')),
                            DropdownMenuItem(value: 'admin', child: Text('Администратор')),
                          ],
                          onChanged: (v) => setState(() => _selectedRole = v!),
                          decoration: const InputDecoration(
                            labelText: 'Роль *',
                            prefixIcon: Icon(Icons.admin_panel_settings),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Colors.white))
                        : ElevatedButton(
                      onPressed: _createUser,
                      child: const Text('Создать пользователя'),
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
