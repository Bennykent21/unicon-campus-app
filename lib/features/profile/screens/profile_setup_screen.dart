import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/department_field.dart';
import '../providers/profile_provider.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  final bool isFirstTime;
  const ProfileSetupScreen({super.key, this.isFirstTime = true});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _universityCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _departmentCtrl =
      TextEditingController(); // own controller so initialValue isn't needed

  String? _selectedLevel;
  File? _avatarFile;
  int _step = 0;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _universityCtrl.dispose();
    _bioCtrl.dispose();
    _departmentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 400,
    );
    if (picked != null) setState(() => _avatarFile = File(picked.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final ok = await ref.read(profileUpdateProvider.notifier).save(
          fullName: _fullNameCtrl.text,
          username: _usernameCtrl.text,
          department: _departmentCtrl.text.trim().isEmpty
              ? null
              : _departmentCtrl.text.trim(),
          level: _selectedLevel,
          university: _universityCtrl.text.trim().isEmpty
              ? null
              : _universityCtrl.text.trim(),
          bio: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
          avatarFile: _avatarFile,
        );

    if (ok && mounted) {
      ref.invalidate(myProfileProvider); // fixed: invalidate instead of refresh
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final updateState = ref.watch(profileUpdateProvider);
    final isLoading = updateState.status == ProfileUpdateStatus.loading;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: widget.isFirstTime
          ? null
          : AppBar(
              title: const Text('Edit Profile'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.pop(),
              ),
            ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.isFirstTime) ...[
                  const SizedBox(height: 16),
                  Text('Set up your profile',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('Let your community know who you are.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.textTheme.bodySmall?.color)),
                  const SizedBox(height: 32),
                ],
                _StepIndicator(current: _step),
                const SizedBox(height: 28),
                if (_step == 0) ...[
                  // ── Step 0: Basic info ──────────────────────────────────────
                  Center(
                    child: GestureDetector(
                      onTap: _pickAvatar,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: context.palette.brandSoft,
                            backgroundImage: _avatarFile != null
                                ? FileImage(_avatarFile!)
                                : null,
                            child: _avatarFile == null
                                ? Icon(Icons.person,
                                    size: 40, color: context.palette.brandText)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: _pickAvatar,
                      child: Text('Upload photo',
                          style: TextStyle(color: context.palette.brandText)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _fullNameCtrl,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter your full name'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixText: '@',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Choose a username';
                      }
                      if (v.contains(' ')) return 'No spaces in username';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _bioCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Bio (optional)',
                      hintText: 'Tell the community about yourself...',
                    ),
                    maxLines: 3,
                    maxLength: 150,
                  ),
                ] else ...[
                  // ── Step 1: University details ──────────────────────────────
                  TextFormField(
                    controller: _universityCtrl,
                    decoration: const InputDecoration(
                      labelText: 'University',
                      hintText: 'e.g. University of Lagos',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 14),
                  DepartmentField(controller: _departmentCtrl),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedLevel,
                    decoration: const InputDecoration(labelText: 'Level'),
                    items: AppConstants.levels
                        .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedLevel = v),
                  ),
                  const SizedBox(height: 8),
                  Text('These help us personalise your feed.',
                      style: theme.textTheme.bodySmall),
                ],
                if (updateState.status == ProfileUpdateStatus.error) ...[
                  const SizedBox(height: 12),
                  Text(
                    updateState.errorMessage ?? 'Something went wrong',
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 28),
                if (_step == 0)
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        setState(() => _step = 1);
                      }
                    },
                    child: const Text('Continue'),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _step = 0),
                          child: const Text('Back'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _save,
                          child: isLoading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Save Profile'),
                        ),
                      ),
                    ],
                  ),
                if (widget.isFirstTime) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: isLoading ? null : () => context.go('/home'),
                    child: Text(
                      'Skip for now',
                      style: TextStyle(
                        color: theme.textTheme.bodySmall?.color,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(2, (i) {
        final active = i == current;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(left: i == 0 ? 0 : 6),
            height: 4,
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primary
                  : AppColors.primary.withValues(
                      alpha: 0.2), // fixed: withValues not withOpacity
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
