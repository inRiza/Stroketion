import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_role.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth_gradient_layout.dart';
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/app_progress_bar.dart';
import '../../widgets/ui/app_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.role});

  final UserRole role;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _totalSteps = 3;

  int _currentStep = 1;
  bool _isLoading = false;
  String _gender = AppStrings.male;

  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 30),
      firstDate: DateTime(1920),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      _dobController.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    }
  }

  void _goBack() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  void _nextStep() {
    GlobalKey<FormState> key;
    switch (_currentStep) {
      case 1:
        key = _step1Key;
      case 2:
        key = _step2Key;
      default:
        key = _step3Key;
    }

    if (!key.currentState!.validate()) return;

    if (_currentStep < _totalSteps) {
      setState(() => _currentStep++);
      return;
    }

    _submitRegister();
  }

  Future<void> _submitRegister() async {
    setState(() => _isLoading = true);

    try {
      await _authService.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
        role: widget.role,
        phone: _phoneController.text.trim(),
        gender: _gender,
        dateOfBirth: _dobController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registrasi berhasil!')),
      );

      Navigator.pushNamedAndRemoveUntil(
        context,
        widget.role.homeRoute,
        (_) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal terhubung ke server')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthGradientLayout(
      compactHeader: true,
      showLogo: false,
      topLeading: IconButton(
        onPressed: _goBack,
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 20,
          color: AppColors.white,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthHeroText(
              title: 'Daftar ${widget.role.label}',
              subtitle: 'Lengkapi data untuk membuat akun',
            ),
            const SizedBox(height: 20),
            AppProgressBar(
              currentStep: _currentStep,
              totalSteps: _totalSteps,
              labels: const [
                AppStrings.stepPersonal,
                AppStrings.stepContact,
                AppStrings.stepAccount,
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: _buildStepContent(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_currentStep > 1)
                  Expanded(
                    child: AppButton(
                      label: AppStrings.back,
                      variant: AppButtonVariant.ghost,
                      onPressed: () => setState(() => _currentStep--),
                    ),
                  ),
                if (_currentStep > 1) const SizedBox(width: 12),
                Expanded(
                  flex: _currentStep > 1 ? 2 : 1,
                  child: AppButton(
                    label: _currentStep == _totalSteps ? AppStrings.finish : AppStrings.next,
                    variant: AppButtonVariant.inverse,
                    isLoading: _isLoading,
                    onPressed: _nextStep,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return Form(
          key: _step1Key,
          child: Column(
            children: [
              AppTextField(
                controller: _nameController,
                label: AppStrings.fullName,
                hint: 'Masukkan nama lengkap',
                prefixIcon: Icons.person_outline,
                authStyle: true,
                validator: (v) => v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 20),
              AppTextField(
                controller: _dobController,
                label: AppStrings.dateOfBirth,
                hint: 'Pilih tanggal lahir',
                prefixIcon: Icons.calendar_today_outlined,
                readOnly: true,
                authStyle: true,
                onTap: _pickDate,
                validator: (v) => v == null || v.isEmpty ? 'Tanggal lahir wajib diisi' : null,
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  AppStrings.gender,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white.withValues(alpha: 0.95),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AuthSelectionTile(
                      label: AppStrings.male,
                      isSelected: _gender == AppStrings.male,
                      centerLabel: true,
                      onTap: () => setState(() => _gender = AppStrings.male),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AuthSelectionTile(
                      label: AppStrings.female,
                      isSelected: _gender == AppStrings.female,
                      centerLabel: true,
                      onTap: () => setState(() => _gender = AppStrings.female),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      case 2:
        return Form(
          key: _step2Key,
          child: Column(
            children: [
              AppTextField(
                controller: _emailController,
                label: AppStrings.email,
                hint: 'contoh@email.com',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                authStyle: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email wajib diisi';
                  if (!v.contains('@')) return 'Format email tidak valid';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              AppTextField(
                controller: _phoneController,
                label: AppStrings.phone,
                hint: '08xxxxxxxxxx',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                authStyle: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Nomor telepon wajib diisi';
                  if (v.length < 10) return 'Nomor telepon tidak valid';
                  return null;
                },
              ),
            ],
          ),
        );
      default:
        return Form(
          key: _step3Key,
          child: Column(
            children: [
              AppTextField(
                controller: _passwordController,
                label: AppStrings.password,
                hint: 'Minimal 6 karakter',
                prefixIcon: Icons.lock_outline,
                obscureText: true,
                authStyle: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password wajib diisi';
                  if (v.length < 6) return 'Minimal 6 karakter';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              AppTextField(
                controller: _confirmPasswordController,
                label: AppStrings.confirmPassword,
                hint: 'Ulangi password',
                prefixIcon: Icons.lock_outline,
                obscureText: true,
                authStyle: true,
                validator: (v) {
                  if (v != _passwordController.text) return 'Password tidak cocok';
                  return null;
                },
              ),
            ],
          ),
        );
    }
  }
}
