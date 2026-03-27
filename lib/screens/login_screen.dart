import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/complaint_store.dart';
import '../services/user_service.dart';
import '../services/ward_assignment_service.dart';
import '../utils/demo_role_router.dart';

/// ROADNIRMAN Login Screen
/// Official, calm, and trustworthy UI for municipal use
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // UI state for password visibility
  bool _obscurePassword = true;
  bool _isLoading = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Enter email and password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Always clear previous session/role before a new login attempt.
      await AuthService.logoutAndSignOut();

      // FIX 5: Every login goes through Supabase Auth. No demo bypass.
      try {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } on AuthException {
        rethrow;
      }

      // Auth succeeded.

      AuthService.setUserFromEmail(email);
      await WardAssignmentService.refresh();
      final dashboard = await loadDashboardForRole(email, password);
      await ComplaintStore.instance.fetchComplaints();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => dashboard),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(
        () => _errorMessage = e.message.isEmpty
            ? 'Wrong password or username'
            : e.message,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Wrong password or username');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Color palette
    const Color primary = Color(0xFF4A5D6B);
    const Color accent = Color(0xFFC9A24D);
    const Color background = Color(0xFFF6F4EF);
    const Color surface = Color(0xFFE7E2D8);
    const Color textPrimary = Color(0xFF2B2B2B);
    const Color textSecondary = Color(0xFF6F6F6F);

    return Scaffold(
      backgroundColor: background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Municipal logo area
              const SizedBox(height: 32),
              // Municipal logo at the very top
              Center(
                child: Image.asset(
                  'assets/favicon_smc.png',
                  height: 64,
                  width: 64,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 24),
              // ROAD NIRMAN logo image
              Center(
                child: Image.asset(
                  'assets/Gemini_Generated_Image_5goo3w5goo3w5goo (1).png',
                  height: 160,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 20),
              // Subtitle (only once)
              // Subtitle
              Text(
                'Solapur Municipal Corporation',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              // Email input
              _InputField(
                controller: _emailController,
                hint: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                background: surface,
                textColor: textPrimary,
                hintColor: textSecondary,
              ),
              const SizedBox(height: 18),
              // Password input
              _InputField(
                controller: _passwordController,
                hint: 'Password',
                icon: Icons.lock_outline,
                obscureText: _obscurePassword,
                background: surface,
                textColor: textPrimary,
                hintColor: textSecondary,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: textSecondary,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                ),
              ),
              const SizedBox(height: 10),
              if (_errorMessage != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              // Forgot password only (no remember me)
              Row(
                children: [
                  const Spacer(),
                  GestureDetector(
                    onTap: () {}, // Dummy callback
                    child: Text(
                      'Forgot password?',
                      style: const TextStyle(
                        fontSize: 14,
                        color: accent,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              // Login button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(_isLoading ? 'Logging in...' : 'Login'),
                ),
              ),
              const SizedBox(height: 24),
              // Register link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'New user?',
                    style: const TextStyle(color: textSecondary, fontSize: 15),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegistrationScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Register here',
                      style: const TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Registration Screen for Citizens
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final mobile = _mobileController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty ||
        email.isEmpty ||
        mobile.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      setState(() => _errorMessage = 'Fill all fields');
      return;
    }
    if (password != confirmPassword) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }
    if (!email.contains('@')) {
      setState(() => _errorMessage = 'Enter a valid email');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name, 'mobile': mobile, 'role': 'citizen'},
      );

      final user = response.user;
      if (user != null) {
        await UserService.instance.upsertProfile({
          'id': user.id,
          'email': email,
          'full_name': name,
          'role': 'citizen',
        });
      }

      if (!mounted) return;

      if (response.session != null) {
        AuthService.setUserFromEmail(email);
        final dashboard = await loadCitizenDashboard();
        await ComplaintStore.instance.fetchComplaints();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => dashboard),
          (route) => false,
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Registration successful. Please verify your email and log in.',
          ),
        ),
      );
      Navigator.pop(context);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Registration failed');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primary = Color(0xFF4A5D6B);
    const Color accent = Color(0xFFC9A24D);
    const Color background = Color(0xFFF6F4EF);
    const Color surface = Color(0xFFE7E2D8);
    const Color textPrimary = Color(0xFF2B2B2B);
    const Color textSecondary = Color(0xFF6F6F6F);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Citizen Registration',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Join Road Nirman',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create an account to report and track road issues in Solapur.',
              style: TextStyle(color: textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 32),
            _InputField(
              controller: _nameController,
              hint: 'Full Name',
              icon: Icons.person_outline,
              background: surface,
              textColor: textPrimary,
              hintColor: textSecondary,
            ),
            const SizedBox(height: 18),
            _InputField(
              controller: _emailController,
              hint: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              background: surface,
              textColor: textPrimary,
              hintColor: textSecondary,
            ),
            const SizedBox(height: 18),
            _InputField(
              controller: _mobileController,
              hint: 'Mobile Number',
              icon: Icons.phone_android_outlined,
              keyboardType: TextInputType.phone,
              background: surface,
              textColor: textPrimary,
              hintColor: textSecondary,
            ),
            const SizedBox(height: 18),
            _InputField(
              controller: _passwordController,
              hint: 'Password',
              icon: Icons.lock_outline,
              obscureText: _obscurePassword,
              background: surface,
              textColor: textPrimary,
              hintColor: textSecondary,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: textSecondary,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            const SizedBox(height: 18),
            _InputField(
              controller: _confirmPasswordController,
              hint: 'Confirm Password',
              icon: Icons.lock_reset_outlined,
              obscureText: _obscurePassword,
              background: surface,
              textColor: textPrimary,
              hintColor: textSecondary,
            ),
            const SizedBox(height: 10),
            if (_errorMessage != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 15),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Register',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'By registering, you agree to the SMC Terms of Service and Privacy Policy.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimalist input field for login screen
class _InputField extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final Color background;
  final Color textColor;
  final Color hintColor;

  const _InputField({
    this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    required this.background,
    required this.textColor,
    required this.hintColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: TextStyle(color: textColor, fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: hintColor),
          suffixIcon: suffixIcon,
          hintText: hint,
          hintStyle: TextStyle(color: hintColor, fontWeight: FontWeight.w400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 14,
          ),
        ),
      ),
    );
  }
}
