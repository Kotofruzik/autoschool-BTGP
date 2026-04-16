import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:parse_server_sdk/parse_server_sdk.dart';
import 'package:url_launcher/url_launcher.dart';

class UserProfilePage extends StatefulWidget {
  final ParseUser user;

  const UserProfilePage({Key? key, required this.user}) : super(key: key);

  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  late ParseUser _user;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  String _getFullName() {
    final surname = _user.get('surname') as String? ?? '';
    final firstname = _user.get('firstname') as String? ?? '';
    final patronymic = _user.get('patronymic') as String? ?? '';
    final parts = [surname, firstname, patronymic].where((s) => s.isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.join(' ');
    final username = _user.get('username') as String? ?? '';
    if (username.isNotEmpty) return username;
    final email = _user.get('email') as String? ?? '';
    if (email.isNotEmpty) return email;
    return 'Имя не указано';
  }

  String _getRole() {
    final role = _user.get('role') as String? ?? '';
    switch (role) {
      case 'instructor':
        return 'Инструктор';
      case 'admin':
        return 'Администратор';
      default:
        return 'Ученик';
    }
  }

  void _launchEmail(String email) async {
    final Uri emailUri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      _showErrorSnackBar('Не удалось открыть почтовое приложение');
    }
  }

  void _launchPhone(String phone) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      _showErrorSnackBar('Не удалось открыть набор номера');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = _user.get('photo') as String? ?? '';
    final email = _user.get('email') as String? ?? '';
    final phone = _user.get('phone') as String? ?? '';
    final surname = _user.get('surname') as String? ?? '';
    final firstname = _user.get('firstname') as String? ?? '';
    final patronymic = _user.get('patronymic') as String? ?? '';
    final createdAt = _user.createdAt;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_getFullName()),
        elevation: 0,
        backgroundColor: Colors.blue,
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
          child: SizedBox.expand(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundImage: photoUrl.isNotEmpty
                                ? CachedNetworkImageProvider(photoUrl)
                                : null,
                            backgroundColor: Colors.blue.shade100,
                            child: photoUrl.isEmpty
                                ? Icon(Icons.person, size: 60, color: Colors.blue)
                                : null,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _getFullName(),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(_getRole(), style: const TextStyle(fontSize: 14)),
                          ),
                          const Divider(height: 32),
                          if (email.isNotEmpty)
                            _buildClickableRow(
                              icon: Icons.email,
                              label: 'Email',
                              value: email,
                              onTap: () => _launchEmail(email),
                            ),
                          if (phone.isNotEmpty)
                            _buildClickableRow(
                              icon: Icons.phone,
                              label: 'Телефон',
                              value: phone,
                              onTap: () => _launchPhone(phone),
                            ),
                          if (surname.isNotEmpty)
                            _buildInfoRow(Icons.person, 'Фамилия', surname),
                          if (firstname.isNotEmpty)
                            _buildInfoRow(Icons.person, 'Имя', firstname),
                          if (patronymic.isNotEmpty)
                            _buildInfoRow(Icons.person, 'Отчество', patronymic),
                          if (createdAt != null)
                            _buildInfoRow(
                              Icons.calendar_today,
                              'Дата регистрации',
                              _formatDate(createdAt),
                            ),
                        ],
                      ),
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

  Widget _buildClickableRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Icon(icon, size: 24, color: Colors.blue),
            const SizedBox(width: 16),
            SizedBox(
              width: 100,
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(decoration: TextDecoration.underline),
              ),
            ),
            const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.blue),
          const SizedBox(width: 16),
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day}.${date.month}.${date.year}';
}