import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/vendor_registry.dart';
import '../../../config/config_store.dart';
import '../../../services/supabase_client.dart';
import '../../../shared/widgets/widgets.dart';

const _builtInUrl  = String.fromEnvironment('COLLEGE_SUPABASE_URL',      defaultValue: '');
const _builtInKey  = String.fromEnvironment('COLLEGE_SUPABASE_ANON_KEY', defaultValue: '');
const _builtInName = String.fromEnvironment('COLLEGE_NAME',              defaultValue: '');
const _builtInId   = String.fromEnvironment('COLLEGE_ID',               defaultValue: '');

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
        supabaseUrl:     college.supabaseUrl!,
        supabaseAnonKey: college.anonKey!,
        collegeName:     college.collegeName,
        collegeId:       college.collegeId,
        setupComplete:   true,
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App icon
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.calendar_month_rounded,
                        color: Colors.white, size: 40),
                  ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.8, 0.8)),
                  const SizedBox(height: 24),

                  Text('Schedulify',
                      style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary,
                          letterSpacing: -0.5))
                      .animate().fadeIn(delay: 150.ms),
                  const SizedBox(height: 8),
                  Text('Multi-tenant college scheduling platform',
                      style: TextStyle(fontSize: 15, color: context.textSecondary),
                      textAlign: TextAlign.center)
                      .animate().fadeIn(delay: 250.ms),
                  const SizedBox(height: 48),

                  // Card
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Enter College ID',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                                color: context.textPrimary)),
                        const SizedBox(height: 4),
                        Text('e.g. DIT-K2X9',
                            style: TextStyle(fontSize: 13, color: context.textSecondary)),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _controller,
                          style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5),
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: 'College ID',
                            hintText: 'XXX-XXXX',
                            prefixIcon: Icon(Icons.business_rounded,
                                color: context.textMuted, size: 20),
                          ),
                          onFieldSubmitted: (_) => _connect(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          ErrorContainer(message: _error!),
                        ],
                        const SizedBox(height: 16),
                        PrimaryButton(
                          label: 'Connect to College',
                          icon: Icons.arrow_forward_rounded,
                          isLoading: _isLoading,
                          width: double.infinity,
                          onPressed: _connect,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 28),
                  GestureDetector(
                    onTap: () => context.go('/setup'),
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: 'New college? ',
                            style: TextStyle(color: context.textSecondary)),
                        const TextSpan(text: 'Set up here →',
                            style: TextStyle(color: AppColors.primary,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ).animate().fadeIn(delay: 500.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
