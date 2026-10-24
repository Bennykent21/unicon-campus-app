import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/department_field.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_scaffold.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _departmentController = TextEditingController();
  final _universityController =
      TextEditingController(text: 'University of Benin');
  String? _level;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _departmentController.dispose();
    _universityController.dispose();
    super.dispose();
  }

  String? _trimmedOrNull(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final success = await ref.read(authNotifierProvider.notifier).signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _fullNameController.text.trim(),
          username: _usernameController.text.trim().replaceAll('@', ''),
          department: _trimmedOrNull(_departmentController),
          level: _level,
          university: _trimmedOrNull(_universityController),
        );
    if (!mounted) return;
    if (success) {
      TextInput.finishAutofillContext();
      if (SupabaseService.isLoggedIn) {
        // Email confirmation is off: the student is signed in already, and
        // the router sends them on to finish their profile.
        context.go('/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Account created. Open the link we emailed you, then log in.')));
        context.go('/login');
      }
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.status == AuthStatus.loading;
    final theme = Theme.of(context);

    // Signup replaces login (context.go), so send back gestures to login
    // instead of closing the app.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/login');
      },
      child: AuthScaffold(
        title: 'Create your account',
        subtitle:
            'Your department and level help us show internships that fit you.',
        children: [
          Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _fullNameController,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.badge_outlined, size: 20),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter your full name'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.newUsername],
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixText: '@',
                      prefixIcon: Icon(Icons.alternate_email, size: 20),
                    ),
                    validator: (v) {
                      final u = (v ?? '').trim().replaceAll('@', '');
                      if (u.isEmpty) return 'Choose a username';
                      if (!RegExp(r'^[a-zA-Z0-9_.]{3,20}$').hasMatch(u)) {
                        return '3 to 20 letters, numbers, dots or underscores';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined, size: 20),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Enter your email';
                      }
                      if (!v.contains('@')) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      helperText: 'At least 6 characters',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                        icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter a password';
                      if (v.length < 6) return 'At least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Text('Your studies', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text('Optional, and you can change them later.',
                      style: theme.textTheme.bodySmall),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _universityController,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'University',
                      prefixIcon: Icon(Icons.school_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DepartmentField(controller: _departmentController),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _level,
                    decoration: const InputDecoration(
                      labelText: 'Level',
                      prefixIcon: Icon(Icons.stairs_outlined, size: 20),
                    ),
                    items: [
                      for (final l in AppConstants.levels)
                        DropdownMenuItem(value: l, child: Text(l)),
                    ],
                    onChanged: (v) => setState(() => _level = v),
                  ),
                ],
              ),
            ),
          ),
          if (authState.status == AuthStatus.error) ...[
            const SizedBox(height: 14),
            AuthErrorBanner(
                message: authState.errorMessage ?? 'Something went wrong.'),
          ],
          const SizedBox(height: 24),
          BusyButton(
              label: 'Create account', busy: isLoading, onPressed: _submit),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Already have an account?',
                  style: theme.textTheme.bodyMedium),
              TextButton(
                onPressed: () => context.go('/login'),
                child: Text('Log in',
                    style: TextStyle(
                        color: context.palette.brandText,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
