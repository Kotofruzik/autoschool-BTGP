import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:autoschool_btgp/services/auth_service.dart';
import 'package:autoschool_btgp/services/edit_profile_page.dart';
import 'package:autoschool_btgp/archive_page.dart';
import 'package:flutter/scheduler.dart';

class StudentProfilePage extends StatefulWidget {
  @override
  _StudentProfilePageState createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> with WidgetsBindingObserver {
  ParseUser? _instructor;
  bool _isLoadingInstructor = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInstructor();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Обновляем данные когда приложение возвращается в активное состояние
    if (state == AppLifecycleState.resumed) {
      print('🔄 Приложение вернулось в активное состояние, обновляем данные инструктора');
      _loadInstructor();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Перезагружаем инструктора при каждом возвращении на страницу
    // Это важно для отображения актуального состояния после открепления
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInstructor();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadInstructor() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;
    
    // Получаем актуальные данные пользователя с сервера через QueryBuilder
    String? instructorId;
    try {
      final query = QueryBuilder<ParseObject>(ParseObject('_User'))
        ..whereEqualTo('objectId', user.objectId);
      final response = await query.query();
      
      if (response.success && response.results != null && response.results!.isNotEmpty) {
        final freshUser = response.results!.first;
        instructorId = freshUser.get('instructorId');
        print('🔍 Получены свежие данные с сервера: instructorId = $instructorId');
        
        // Принудительно обновляем локального пользователя
        if (instructorId == null) {
          user.set('instructorId', null);
          print('✅ Локально очищен instructorId у текущего пользователя');
        }
      } else {
        // Если не удалось получить свежие данные, используем локальные
        instructorId = user.get('instructorId');
        print('⚠️ Не удалось получить свежие данные, используем локальные: instructorId = $instructorId');
      }
    } catch (e) {
      print('❌ Ошибка при получении данных пользователя: $e');
      instructorId = user.get('instructorId');
    }
    
    print('🔍 Проверка instructorId: текущее значение = $instructorId');
    
    if (instructorId == null) {
      print('✅ Ученик не имеет инструктора (instructorId = null)');
      if (mounted) {
        setState(() {
          _instructor = null;
          _isLoadingInstructor = false;
        });
      }
      return;
    }

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
          print('✅ Инструктор загружен: ${data['firstName']} ${data['lastName']}');
        }
      } else {
        print('❌ Ошибка получения инструктора: ${response.error?.message}');
        // Если ошибка - возможно инструктор был удален или откреплен
        if (mounted) {
          setState(() {
            _instructor = null;
          });
        }
      }
    } catch (e) {
      print('❌ Ошибка загрузки инструктора: $e');
      if (mounted) {
        setState(() {
          _instructor = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingInstructor = false);
      }
    }
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