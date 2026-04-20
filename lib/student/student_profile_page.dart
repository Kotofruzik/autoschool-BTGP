import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:autoschool_btgp/services/auth_service.dart';
import 'package:autoschool_btgp/services/edit_profile_page.dart';
import 'package:autoschool_btgp/archive_page.dart';
import 'package:autoschool_btgp/services/lesson_service.dart';
import 'package:autoschool_btgp/lesson/lesson_model.dart';

class StudentProfilePage extends StatefulWidget {
  final Function(bool?)? onDetach;
  
  const StudentProfilePage({Key? key, this.onDetach}) : super(key: key);
  
  @override
  _StudentProfilePageState createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  ParseUser? _instructor;
  bool _isLoadingInstructor = false;

  @override
  void initState() {
    super.initState();
    _loadInstructor();
  }

  Future<void> _loadInstructor() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    final instructorId = user?.get('instructorId');
    if (instructorId == null) return;

    if (!mounted) return;
    setState(() => _isLoadingInstructor = true);

    try {
      final function = ParseCloudFunction('getInstructorName');
      final response = await function.execute(parameters: {'instructorId': instructorId});
      if (response.success && response.result != null) {
        final data = response.result as Map<String, dynamic>;
        if (mounted) {
          final tempUser = ParseUser(null, null, null);
          tempUser.set('firstname', data['firstName']);
          tempUser.set('surname', data['lastName']);
          tempUser.set('patronymic', data['patronymic']);
          setState(() {
            _instructor = tempUser;
          });
        }
      } else {
        print('❌ Ошибка получения инструктора: ${response.error?.message}');
      }
    } catch (e) {
      print('❌ Ошибка загрузки инструктора: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingInstructor = false);
      }
    }
  }

  Future<void> _detachFromInstructor() async {
    print('🔄 Начинаем открепление от инструктора...');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Открепление от инструктора'),
        content: const Text('Вы уверены, что хотите открепиться от текущего инструктора? Все назначенные занятия будут отменены.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Открепиться'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      print('⏹️ Пользователь отменил открепление');
      return;
    }

    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) {
      print('❌ Пользователь не авторизован');
      return;
    }

    final instructorId = user.get('instructorId') as String?;
    if (instructorId != null) {
      print('🗑️ Отменяем занятия с инструктором $instructorId');
      final lessonService = LessonService();
      final allLessons = await lessonService.getLessonsForStudent(user);
      final lessonsToCancel = allLessons.where((obj) {
        final lesson = Lesson.fromParse(obj);
        final lessonInstructor = lesson.instructor;
        return lessonInstructor != null &&
            lessonInstructor.objectId == instructorId &&
            lesson.status != 'cancelled' &&
            lesson.status != 'completed';
      }).toList();

      for (final lessonObj in lessonsToCancel) {
        lessonObj.set('status', 'cancelled');
        await lessonObj.save();
      }
      print('✅ Занятия отменены: ${lessonsToCancel.length}');
    }

    user.set('instructorId', null);
    await user.save();
    print('💾 Пользователь сохранён без инструктора');

    auth.setCurrentUser(user);

    if (mounted) {
      setState(() {
        _instructor = null;
      });
    }

    // 🔧 Исправлено: откладываем навигацию до следующего кадра
    // и проверяем, можно ли сделать pop
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Сообщаем родительскому виджету об откреплении
      widget.onDetach?.call(true);

      if (Navigator.canPop(context)) {
        print('🔃 Выполняем Navigator.pop');
        Navigator.pop(context, true);
      } else {
        print('⚠️ Нечего pop\'ить, возвращаемся к корню');
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    });
  }

  Future<void> _scanQrCode() async {
    try {
      print('📷 Запускаем сканер QR-кода');
      final String? scannedId = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (context) => MobileScannerPage()),
      );

      if (scannedId == null) {
        print('⏹️ Сканирование отменено или не удалось');
        return;
      }

      print('✅ Отсканирован ID: $scannedId');

      final auth = Provider.of<AuthService>(context, listen: false);
      final user = auth.currentUser;
      if (user == null) return;

      user.set('instructorId', scannedId);
      await user.save();
      auth.setCurrentUser(user);

      await _loadInstructor();
      print('🔗 Инструктор привязан');
    } catch (e) {
      print('❌ Ошибка при сканировании: $e');
    }
  }

  void _editProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditProfilePage()),
    );
  }

  String _getFullName(ParseUser? user) {
    if (user == null) return 'Без имени';
    String surname = user.get('surname') ?? '';
    String firstname = user.get('firstname') ?? '';
    List<String> parts = [surname, firstname].where((s) => s.isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.join(' ');
    final username = user.get('username');
    if (username != null && username.isNotEmpty) {
      if (username.contains('@')) return username.split('@')[0];
      return username;
    }
    return 'Пользователь';
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;
    final photoUrl = user?.get('photo') as String?;
    final phone = user?.get('phone') as String? ?? 'Не указан';
    final email = user?.get('email') as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editProfile(context),
          ),
        ],
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
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white,
                  backgroundImage: photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
                  child: photoUrl == null
                      ? const Icon(Icons.person, size: 60, color: Colors.blue)
                      : null,
                ),
                const SizedBox(height: 20),
                Text(
                  _getFullName(user),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.phone, color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    Text(phone, style: const TextStyle(fontSize: 16, color: Colors.white70)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.email, color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    Text(email, style: const TextStyle(fontSize: 16, color: Colors.white70)),
                  ],
                ),
                const SizedBox(height: 20),

                if (_isLoadingInstructor)
                  const CircularProgressIndicator(color: Colors.white)
                else if (_instructor != null)
                  Column(
                    children: [
                      const Divider(color: Colors.white70),
                      const Text('Ваш инструктор:',
                          style: TextStyle(color: Colors.white70, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(
                        _getFullName(_instructor),
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _detachFromInstructor,
                        icon: const Icon(Icons.link_off, size: 18),
                        label: const Text('Открепиться'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                        ),
                      ),
                    ],
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _scanQrCode,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Привязаться к инструктору'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue,
                    ),
                  ),

                const SizedBox(height: 20),

                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ArchivePage()),
                    );
                  },
                  icon: const Icon(Icons.archive),
                  label: const Text('Архив занятий'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue,
                    minimumSize: const Size(double.infinity, 45),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MobileScannerPage extends StatefulWidget {
  @override
  _MobileScannerPageState createState() => _MobileScannerPageState();
}

class _MobileScannerPageState extends State<MobileScannerPage> {
  MobileScannerController? _controller;
  bool _isDetected = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сканируйте QR-код инструктора'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_isDetected) return;
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
                  _isDetected = true;
                  _controller?.stop();
                  Navigator.pop(context, barcode.rawValue!);
                  return;
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}