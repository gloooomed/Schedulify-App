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
  final _formKey  = GlobalKey<FormState>();
  final _email    = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;
  bool _isLoading    = false;
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
      final user  = ref.read(currentUserProvider);
      final role  = user?.role ?? 'student';
      final route = switch (role) {
        'super_admin' || 'admin' => '/admin',
        'faculty'                => '/faculty',
        _                        => '/student',
      };
      context.go(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Icon
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(Icons.lock_rounded,
                          color: Colors.white, size: 38),
                    ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.8, 0.8)),
                    const SizedBox(height: 24),

                    Text('Welcome back',
                        style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                            letterSpacing: -0.5))
                        .animate().fadeIn(delay: 150.ms),
                    const SizedBox(height: 8),
                    Text('Sign in to your account',
                        style: TextStyle(fontSize: 15, color: context.textSecondary))
                        .animate().fadeIn(delay: 250.ms),
                    const SizedBox(height: 40),

                    // Form card
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Email field with explicit label above
                          Text('Email',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                                  color: context.textSecondary)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(color: context.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'your@college.edu',
                              prefixIcon: Icon(Icons.email_outlined,
                                  color: context.textMuted, size: 20),
                            ),
                            validator: (v) =>
                                v != null && v.contains('@') ? null : 'Enter valid email',
                          ),
                          const SizedBox(height: 16),

                          // Password field
                          Text('Password',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                                  color: context.textSecondary)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _password,
                            obscureText: !_showPassword,
                            style: TextStyle(color: context.textPrimary),
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              prefixIcon: Icon(Icons.lock_outline_rounded,
                                  color: context.textMuted, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: context.textMuted, size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => _showPassword = !_showPassword),
                              ),
                            ),
                            validator: (v) =>
                                v != null && v.length >= 6 ? null : 'Min 6 characters',
                          ),

                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            ErrorContainer(message: _error!),
                          ],
                          const SizedBox(height: 24),

                          PrimaryButton(
                            label: 'Sign In',
                            isLoading: _isLoading,
                            width: double.infinity,
                            onPressed: _login,
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1, end: 0),

                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () {}, // placeholder — no forgot-password flow yet
                      child: const Text('Forgot password?',
                          style: TextStyle(color: AppColors.primary,
                              fontWeight: FontWeight.w500)),
                    ).animate().fadeIn(delay: 500.ms),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
