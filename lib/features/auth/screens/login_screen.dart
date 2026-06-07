import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../core/utils/pwa_prompt.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PwaPrompt.showIfNeeded(context);
    });
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _error = null; });

    final error = await ref.read(authProvider.notifier).login(
      _email.text.trim(),
      _password.text,
    );

    if (!mounted) return;
    if (error != null) {
      setState(() { _error = error; _isLoading = false; });
    } else {
      final user = ref.read(currentUserProvider);
      final role = user?.role ?? 'student';
      final route = switch (role) {
        'super_admin' || 'admin' => '/admin',
        'faculty' => '/faculty',
        _ => '/student',
      };
      context.go(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => context.go('/'),
                          icon: const Icon(Icons.arrow_back, size: 18,
                              color: AppColors.textSecondary),
                          label: const Text('Change College',
                              style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      ),
                      const SizedBox(height: 32),

                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          gradient: AppGradients.primary,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.lock_rounded, color: Colors.white, size: 30),
                      ).animate().fadeIn(duration: 500.ms).scale(),
                      const SizedBox(height: 20),
                      const Text('Welcome back',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary))
                          .animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 8),
                      const Text('Sign in to your account',
                          style: TextStyle(fontSize: 15, color: AppColors.textSecondary))
                          .animate().fadeIn(delay: 300.ms),
                      const SizedBox(height: 40),

                      GlassCard(
                        child: Column(
                          children: [
                            AppTextField(
                              controller: _email,
                              label: 'Email',
                              hint: 'your@college.edu',
                              keyboardType: TextInputType.emailAddress,
                              prefixIcon: Icons.email_outlined,
                              validator: (v) =>
                                  v != null && v.contains('@') ? null : 'Enter valid email',
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              controller: _password,
                              label: 'Password',
                              obscureText: !_showPassword,
                              prefixIcon: Icons.lock_outline,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showPassword ? Icons.visibility_off : Icons.visibility,
                                  color: AppColors.textMuted, size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => _showPassword = !_showPassword),
                              ),
                              validator: (v) =>
                                  v != null && v.length >= 6 ? null : 'Min 6 characters',
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: AppColors.danger.withOpacity(0.3)),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.error_outline,
                                      color: AppColors.danger, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(_error!,
                                      style: const TextStyle(
                                          color: AppColors.danger, fontSize: 13))),
                                ]),
                              ),
                            ],
                            const SizedBox(height: 24),
                            PrimaryButton(
                              label: 'Sign In',
                              icon: Icons.login_rounded,
                              isLoading: _isLoading,
                              width: double.infinity,
                              onPressed: _login,
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.15, end: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
