import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:autoschool_btgp/services/auth_service.dart';

class EditProfilePage extends StatefulWidget {
  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _firstNameController;
  late TextEditingController _surnameController;
  late TextEditingController _patronymicController;
  late TextEditingController _phoneController;

  CroppedFile? _newCroppedImage;
  bool _isUploading = false;
  bool _isSaving = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    _firstNameController = TextEditingController(text: user?.get('firstname') ?? '');
    _surnameController = TextEditingController(text: user?.get('surname') ?? '');
    _patronymicController = TextEditingController(text: user?.get('patronymic') ?? '');
    _phoneController = TextEditingController(text: user?.get('phone') ?? '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _surnameController.dispose();
    _patronymicController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

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

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    try {
      user.set('firstname', _firstNameController.text.trim());
      user.set('surname', _surnameController.text.trim());
      user.set('patronymic', _patronymicController.text.trim());
      user.set('phone', _phoneController.text.trim());

      if (_newCroppedImage != null) {
        setState(() => _isUploading = true);
        final xFile = XFile(_newCroppedImage!.path);
        String? error = await auth.uploadProfilePhoto(xFile);
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
          setState(() {
            _isUploading = false;
            _isSaving = false;
          });
          return;
        }
      }

      await user.save();
      auth.setCurrentUser(user);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Профиль обновлён'), backgroundColor: Colors.green),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isUploading = false;
        _isSaving = false;
      });
    }
  }

  Future<void> _changePassword() async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Смена пароля'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Старый пароль'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Новый пароль'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Подтвердите пароль'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () {
              if (newPasswordController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Пароль должен быть не менее 6 символов'), backgroundColor: Colors.red),
                );
                return;
              }
              if (newPasswordController.text != confirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Пароли не совпадают'), backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (result == true) {
      final auth = Provider.of<AuthService>(context, listen: false);
      final user = auth.currentUser;
      if (user == null) return;

      try {
        final function = ParseCloudFunction('changePassword');
        final response = await function.execute(parameters: {
          'oldPassword': oldPasswordController.text,
          'newPassword': newPasswordController.text,
        });

        if (response.success) {
          final email = user.get('email') ?? user.get('username');
          final loginError = await auth.loginWithEmail(email, newPasswordController.text);
          if (loginError == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Пароль успешно изменён'), backgroundColor: Colors.green),
            );
            Navigator.pop(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Пароль изменён, но не удалось войти. Пожалуйста, войдите заново.'),
                backgroundColor: Colors.orange,
              ),
            );
            await auth.signOut();
            Navigator.pushReplacementNamed(context, '/login');
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.error?.message ?? 'Ошибка'), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _signOut() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    await auth.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удаление профиля'),
        content: const Text('Вы уверены? Все ваши данные будут безвозвратно удалены.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (confirm == true) {
      final auth = Provider.of<AuthService>(context, listen: false);
      String? error = await auth.deleteAccount();
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  // Скрыть клавиатуру при тапе вне полей
  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;
    final currentPhotoUrl = user?.get('photo') as String?;
    final isGoogleUser = user?.get('authData') != null;

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.lightBlueAccent],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          // resizeToAvoidBottomInset по умолчанию true → экран сжимается при клавиатуре
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              (_isUploading || _isSaving)
                  ? const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              )
                  : IconButton(
                icon: const Icon(Icons.check),
                onPressed: _saveChanges,
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 5),
                  // Аватар
                  GestureDetector(
                    onTap: _pickAndCropImage,
                    child: Stack(
                      children: [
                        Container(
                          width: 140,
                          height: 140,
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
                                : (currentPhotoUrl != null
                                ? DecorationImage(
                              image: CachedNetworkImageProvider(currentPhotoUrl),
                              fit: BoxFit.cover,
                            )
                                : null),
                          ),
                          child: (currentPhotoUrl == null && _newCroppedImage == null)
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
                                color: Colors.blue, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          TextField(
                            controller: _firstNameController,
                            decoration: const InputDecoration(
                              labelText: 'Имя',
                              prefixIcon: Icon(Icons.person, color: Colors.blue),
                              border: InputBorder.none,
                            ),
                          ),
                          const Divider(),
                          TextField(
                            controller: _surnameController,
                            decoration: const InputDecoration(
                              labelText: 'Фамилия',
                              prefixIcon: Icon(Icons.person_outline, color: Colors.blue),
                              border: InputBorder.none,
                            ),
                          ),
                          const Divider(),
                          TextField(
                            controller: _patronymicController,
                            decoration: const InputDecoration(
                              labelText: 'Отчество',
                              prefixIcon: Icon(Icons.person, color: Colors.blue),
                              border: InputBorder.none,
                            ),
                          ),
                          const Divider(),
                          TextField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Телефон',
                              prefixIcon: Icon(Icons.phone, color: Colors.blue),
                              border: InputBorder.none,
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  if (!isGoogleUser)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.lock, color: Colors.blue),
                        title: const Text('Изменить пароль'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: _changePassword,
                      ),
                    ),

                  const SizedBox(height: 10),

                  ElevatedButton(
                    onPressed: _signOut,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Выйти из профиля',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 8),

                  TextButton(
                    onPressed: _deleteAccount,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      minimumSize: const Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Удалить профиль',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}