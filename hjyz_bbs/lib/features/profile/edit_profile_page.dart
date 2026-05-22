import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_client.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/safe_network_image.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  bool loading = true;
  bool saving = false;
  bool uploadingAvatar = false;

  String avatarUrl = '';
  File? avatarFile;

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

      avatarUrl = data['avatar']?.toString() ?? '';
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

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (picked == null) return;

    setState(() {
      avatarFile = File(picked.path);
    });

    await _uploadAvatar();
  }

  Future<void> _uploadAvatar() async {
    if (avatarFile == null) return;

    setState(() {
      uploadingAvatar = true;
    });

    final result = await ApiClient.instance.uploadFile(
      'upload/media',
      file: avatarFile!,
      fields: {'type': 'image'},
    );

    if (!mounted) return;

    setState(() {
      uploadingAvatar = false;
    });

    if (result.success && result.data is Map<String, dynamic>) {
      final data = result.data as Map<String, dynamic>;
      setState(() {
        avatarUrl = data['url']?.toString() ?? '';
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('头像上传失败：${result.message}')),
      );
    }
  }

  Future<void> _save() async {
    setState(() {
      saving = true;
    });

    final result = await ApiClient.instance.post(
      'profile/update',
      data: {
        'avatar': avatarUrl,
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

  Widget _buildAvatarSection() {
    return Center(
      child: GestureDetector(
        onTap: uploadingAvatar ? null : _pickAvatar,
        child: Stack(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: avatarFile != null
                    ? Image.file(
                        avatarFile!,
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                      )
                    : SafeNetworkImage(
                        url: avatarUrl,
                        width: 96,
                        height: 96,
                        errorWidget: CircleAvatar(
                          radius: 48,
                          backgroundColor: Colors.pink.shade50,
                          child: const Icon(Icons.person, size: 40),
                        ),
                      ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFB7299),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: uploadingAvatar
                    ? const Padding(
                        padding: EdgeInsets.all(6),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: Colors.white,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
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
          _buildAvatarSection(),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '点击更换头像',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ),
          const SizedBox(height: 20),
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
