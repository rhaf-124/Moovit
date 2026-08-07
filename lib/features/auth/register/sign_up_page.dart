import 'dart:io';

import 'package:bus_ticketing/core/router/app_router.dart';
import 'package:bus_ticketing/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../presentation/cubit/auth_cubit.dart';
import '../presentation/cubit/auth_state.dart';

// Import your LoginPage
// import 'login_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage>
    with SingleTickerProviderStateMixin {
  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Profile image
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  // Text controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Focus nodes
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  // Error messages
  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String? _passwordError;
  String? _confirmPasswordError;

  // UI states
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoadingEmail = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  // ---------- Pick Profile Image ----------
  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery, // or ImageSource.camera
      imageQuality: 80,
    );
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  // ---------- Validations (same as before) ----------
  bool _validateName() {
    setState(() => _nameError = null);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Full name is required');
      return false;
    }
    if (name.length < 2) {
      setState(() => _nameError = 'Name must be at least 2 characters');
      return false;
    }
    return true;
  }

  bool _validateEmail() {
    setState(() => _emailError = null);
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _emailError = 'Email address is required');
      return false;
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _emailError = 'Please enter a valid email address');
      return false;
    }
    return true;
  }

  bool _validatePhone() {
    setState(() => _phoneError = null);
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _phoneError = 'Phone number is required');
      return false;
    }
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 9 || digitsOnly.length > 15) {
      setState(
        () => _phoneError = 'Please enter a valid phone number (9-15 digits)',
      );
      return false;
    }
    return true;
  }

  bool _validatePassword() {
    setState(() => _passwordError = null);
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _passwordError = 'Password is required');
      return false;
    }
    if (password.length < 6) {
      setState(() => _passwordError = 'Password must be at least 6 characters');
      return false;
    }
    return true;
  }

  bool _validateConfirmPassword() {
    setState(() => _confirmPasswordError = null);
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    if (confirm.isEmpty) {
      setState(() => _confirmPasswordError = 'Please confirm your password');
      return false;
    }
    if (password != confirm) {
      setState(() => _confirmPasswordError = 'Passwords do not match');
      return false;
    }
    return true;
  }

  Future<void> _signUpWithEmail() async {
    if (!_validateName() ||
        !_validateEmail() ||
        !_validatePhone() ||
        !_validatePassword() ||
        !_validateConfirmPassword()) {
      return;
    }
    setState(() => _isLoadingEmail = true);
    context.read<AuthCubit>().register(
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          fullName: _nameController.text.trim(),
          password: _passwordController.text,
        );
  }

  void _clearFieldError(String field) {
    setState(() {
      if (field == 'name') _nameError = null;
      if (field == 'email') _emailError = null;
      if (field == 'phone') _phoneError = null;
      if (field == 'password') _passwordError = null;
      if (field == 'confirmPassword') _confirmPasswordError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final cardWidth = isSmallScreen ? screenWidth * 0.92 : 480.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthRegistrationEmailSent) {
          setState(() => _isLoadingEmail = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Account created! Enter the 6-digit code we emailed you to verify your account.',
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
          context.go(AppRoutes.verifyEmail, extra: state.email);
        } else if (state is AuthError) {
          setState(() => _isLoadingEmail = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      },
      child: Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 16.0 : 24.0,
              vertical: 24.0,
            ),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  width: cardWidth,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurface
                        : AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? AppColors.lightBackground
                            : AppColors.darkOnSurfaceVariant,
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28.0,
                      vertical: 36.0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Profile Photo Picker (replaces logo)
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            height: 100,
                            width: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade600,
                                  Colors.indigo.shade700,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.shade200,
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.transparent,
                              backgroundImage: _profileImage != null
                                  ? FileImage(_profileImage!)
                                  : null,
                              child: _profileImage == null
                                  ? Icon(
                                      Icons.camera_alt,
                                      size: 40,
                                      color: Colors.white70,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tap to add profile photo',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Welcome Text
                        Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 28 : 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign up to get started',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // Full Name
                        TextFormField(
                          controller: _nameController,
                          focusNode: _nameFocusNode,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _clearFieldError('name'),
                          onFieldSubmitted: (_) =>
                              _emailFocusNode.requestFocus(),
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            hintText: 'John Doe',
                            prefixIcon: Icon(
                              Icons.person_outline,
                              color: Colors.indigo.shade400,
                            ),
                            errorText: _nameError,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Email
                        TextFormField(
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _clearFieldError('email'),
                          onFieldSubmitted: (_) =>
                              _phoneFocusNode.requestFocus(),
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            hintText: 'hello@example.com',
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: Colors.indigo.shade400,
                            ),
                            errorText: _emailError,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Phone
                        TextFormField(
                          controller: _phoneController,
                          focusNode: _phoneFocusNode,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => _clearFieldError('phone'),
                          onFieldSubmitted: (_) =>
                              _passwordFocusNode.requestFocus(),
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            hintText: '+233 XX XXX XXXX',
                            prefixIcon: Icon(
                              Icons.phone_android_outlined,
                              color: Colors.indigo.shade400,
                            ),
                            errorText: _phoneError,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Password
                        TextFormField(
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _clearFieldError('password'),
                          onFieldSubmitted: (_) =>
                              _confirmPasswordFocusNode.requestFocus(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: '••••••••',
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: Colors.indigo.shade400,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.grey.shade500,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                            errorText: _passwordError,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Confirm Password
                        TextFormField(
                          controller: _confirmPasswordController,
                          focusNode: _confirmPasswordFocusNode,
                          obscureText: _obscureConfirmPassword,
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => _clearFieldError('confirmPassword'),
                          onFieldSubmitted: (_) => _signUpWithEmail(),
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            hintText: '••••••••',
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: Colors.indigo.shade400,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.grey.shade500,
                              ),
                              onPressed: () => setState(
                                () => _obscureConfirmPassword =
                                    !_obscureConfirmPassword,
                              ),
                            ),
                            errorText: _confirmPasswordError,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Email Sign Up
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoadingEmail
                                ? null
                                : _signUpWithEmail,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo.shade700,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: _isLoadingEmail
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    'Sign Up',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Sign In Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Already have an account? ",
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            GestureDetector(
                              onTap: () => context.go(AppRoutes.login),
                              child: Text(
                                'Sign In',
                                style: TextStyle(
                                  color: Colors.indigo.shade700,
                                  fontWeight: FontWeight.bold,
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
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}
