import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/widgets/loading_view.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  bool loading = true;
  bool saving = false;

  final nicknameController = TextEditingController();
  final bioController = TextEditingController();
  final genderController = TextEditingController();
  final birthdayController = TextEditingController();
  final schoolController = TextEditingController();
  final gradeController = TextEditingController();
  final locationController = TextEditingController();

  Map<String, bool> visibility = {
    'gender': true,
    'birthday': false,
    'school': true,
    'grade': true,
    'location': true,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    nicknameController.dispose();
    bioController.dispose();
    genderController.dispose();
    birthdayController.dispose();
    schoolController.dispose();
    gradeController.dispose();
    locationController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final result = await ApiClient.instance.get('profile/get');

    if (!mounted) return;

    if (result.success && result.data is Map<String, dynamic>) {
      final data = result.data as Map<String, dynamic>;

      nicknameController.text = data['nickname']?.toString() ?? '';
      bioController.text = data['bio']?.toString() ?? '';
      genderController.text = data['gender']?.toString() ?? '';
      birthdayController.text = data['birthday']?.toString() ?? '';
      schoolController.text = data['school']?.toString() ?? '';
      gradeController.text = data['grade']?.toString() ?? '';
      locationController.text = data['location']?.toString() ?? '';

      final rawVisibility = data['visibility'];

      if (rawVisibility is Map) {
        visibility = rawVisibility.map(
          (key, value) => MapEntry(key.toString(), value == true),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }

    setState(() {
      loading = false;
    });
  }

  Future<void> _save() async {
    setState(() {
      saving = true;
    });

    final result = await ApiClient.instance.post(
      'profile/update',
      data: {
        'nickname': nicknameController.text.trim(),
        'bio': bioController.text.trim(),
        'gender': genderController.text.trim(),
        'birthday': birthdayController.text.trim(),
        'school': schoolController.text.trim(),
        'grade': gradeController.text.trim(),
        'location': locationController.text.trim(),
        'visibility': visibility,
      },
    );

    if (!mounted) return;

    setState(() {
      saving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );

    if (result.success) {
      Navigator.of(context).pop(true);
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _visibilityTile(String key, String title) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('$title 在个人主页显示'),
      value: visibility[key] ?? false,
      onChanged: (value) {
        setState(() {
          visibility[key] = value;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: LoadingView(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑资料'),
        actions: [
          TextButton(
            onPressed: saving ? null : _save,
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _field('昵称', nicknameController),
          _field('简介', bioController, maxLines: 3),
          _field('性别', genderController),
          _visibilityTile('gender', '性别'),
          _field('生日，格式：YYYY-MM-DD', birthdayController),
          _visibilityTile('birthday', '生日'),
          _field('学校', schoolController),
          _visibilityTile('school', '学校'),
          _field('年级/班级', gradeController),
          _visibilityTile('grade', '年级/班级'),
          _field('地区', locationController),
          _visibilityTile('location', '地区'),
        ],
      ),
    );
  }
}
