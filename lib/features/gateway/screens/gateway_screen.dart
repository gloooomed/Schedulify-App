import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/vendor_registry.dart';
import '../../../config/config_store.dart';
import '../../../services/supabase_client.dart';
import '../../../shared/widgets/widgets.dart';

const _builtInUrl    = String.fromEnvironment('COLLEGE_SUPABASE_URL',  defaultValue: '');
const _builtInKey    = String.fromEnvironment('COLLEGE_SUPABASE_ANON_KEY', defaultValue: '');
const _builtInName   = String.fromEnvironment('COLLEGE_NAME',  defaultValue: '');
const _builtInId     = String.fromEnvironment('COLLEGE_ID',    defaultValue: '');

class GatewayScreen extends StatefulWidget {
  const GatewayScreen({super.key});

  @override
  State<GatewayScreen> createState() => _GatewayScreenState();
}

class _GatewayScreenState extends State<GatewayScreen> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_builtInUrl.isNotEmpty && _builtInKey.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoConnect());
    }
  }

  Future<void> _autoConnect() async {
    setState(() { _isLoading = true; _error = null; });
    await ConfigStore.instance.set(AppConfig(
      supabaseUrl:     _builtInUrl,
      supabaseAnonKey: _builtInKey,
      collegeName:     _builtInName.isNotEmpty ? _builtInName : null,
      collegeId:       _builtInId.isNotEmpty   ? _builtInId   : null,
      setupComplete:   true,
    ));
    SupabaseClientManager.instance.reset();
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) context.go('/login');
  }

  Future<void> _connect() async {
    final id = _controller.text.trim().toUpperCase();
    if (id.isEmpty) return;
    setState(() { _isLoading = true; _error = null; });

    try {
      final college = await VendorRegistry.instance
          .getCollegeConfig(id)
          .timeout(const Duration(seconds: 15));
      if (college == null) {
        setState(() { _error = 'College not found. Check the ID.'; _isLoading = false; });
        return;
      }
      if (college.supabaseUrl == null || college.anonKey == null) {
        setState(() { _error = 'College setup is incomplete. Contact your administrator.'; _isLoading = false; });
        return;
      }
      await ConfigStore.instance.set(AppConfig(
        supabaseUrl: college.supabaseUrl!,
        supabaseAnonKey: college.anonKey!,
        collegeName: college.collegeName,
        collegeId: college.collegeId,
        setupComplete: true,
      ));
      SupabaseClientManager.instance.reset();
      if (mounted) context.go('/login');
    } on TimeoutException {
      setState(() { _error = 'Connection timed out. Check your internet.'; _isLoading = false; });
    } catch (e) {
      setState(() { _error = 'Could not connect. Check your internet connection.'; _isLoading = false; });
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        gradient: AppGradients.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.schedule_rounded, color: Colors.white, size: 36),
                    ).animate().fadeIn(duration: 600.ms).scale(),
                    const SizedBox(height: 20),
                    const Text('Schedulify',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary))
                        .animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 8),
                    const Text('Multi-tenant college scheduling platform',
                        style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                        textAlign: TextAlign.center)
                        .animate().fadeIn(delay: 300.ms),
                    const SizedBox(height: 48),

                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Enter College ID',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 6),
                          const Text('e.g. DIT-K2X9',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _controller,
                            style: const TextStyle(color: AppColors.textPrimary,
                                fontSize: 18, fontWeight: FontWeight.w600,
                                letterSpacing: 2),
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              hintText: 'XXX-XXXX',
                              prefixIcon: Icon(Icons.school_rounded,
                                  color: AppColors.textMuted),
                            ),
                            onFieldSubmitted: (_) => _connect(),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                              ),
                              child: Row(children: [
                                const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_error!,
                                    style: const TextStyle(color: AppColors.danger, fontSize: 13))),
                              ]),
                            ),
                          ],
                          const SizedBox(height: 20),
                          PrimaryButton(
                            label: 'Connect to College',
                            icon: Icons.arrow_forward_rounded,
                            isLoading: _isLoading,
                            width: double.infinity,
                            onPressed: _connect,
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.15, end: 0),

                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () => context.go('/setup'),
                      child: const Text.rich(
                        TextSpan(children: [
                          TextSpan(text: "New college? ", style: TextStyle(color: AppColors.textSecondary)),
                          TextSpan(text: "Set up here →", style: TextStyle(color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ).animate().fadeIn(delay: 600.ms),
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
