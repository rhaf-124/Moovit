import 'package:bus_ticketing/core/router/app_router.dart';
import 'package:bus_ticketing/core/utils/error_formatter.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../domain/repositories/auth_repository.dart';

class VerifyEmailPage extends StatefulWidget {
  final String email;
  const VerifyEmailPage({super.key, required this.email});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  late List<FocusNode> _rawFocusNodes;
  bool _isLoading = false;
  bool _isResending = false;
  int _resendSeconds = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(6, (_) => TextEditingController());
    _focusNodes = List.generate(6, (_) => FocusNode());
    _rawFocusNodes = List.generate(6, (_) => FocusNode());
    _startResendTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNodes[0]);
    });
  }

  void _startResendTimer() {
    _canResend = false;
    _resendSeconds = 60;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      if (_resendSeconds <= 1) {
        setState(() => _canResend = true);
        return false;
      }
      setState(() => _resendSeconds--);
      return true;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    for (final f in _rawFocusNodes) { f.dispose(); }
    super.dispose();
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_otpCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the full 6-digit code')),
      );
      return;
    }
    setState(() => _isLoading = true);

    final repo = RepositoryProvider.of<AuthRepository>(context);

    try {
      await repo.verifyEmail(widget.email, _otpCode);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Email verified successfully! Please log in with your credentials.',
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      context.go(AppRoutes.login);
    } catch (e) {
      if (!mounted) return;
      final message = e is DioException && e.response?.data is Map
          ? (e.response!.data as Map)['detail']?.toString() ?? friendlyError(e)
          : friendlyError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      for (final c in _controllers) { c.clear(); }
      FocusScope.of(context).requestFocus(_focusNodes[0]);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    if (!_canResend || _isResending) return;
    setState(() => _isResending = true);

    final repo = RepositoryProvider.of<AuthRepository>(context);

    try {
      await repo.resendVerificationCode(widget.email);
      if (!mounted) return;
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A new code has been sent'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to resend. Try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Widget _buildOtpField(int index, double size) {
    return SizedBox(
      width: size,
      height: size * 1.2,
      child: KeyboardListener(
        focusNode: _rawFocusNodes[index],
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace) {
            if (_controllers[index].text.isEmpty && index > 0) {
              _controllers[index - 1].clear();
              FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
            }
          }
        },
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black87,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey.shade800
                : Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor,
                width: 2.5,
              ),
            ),
            contentPadding: EdgeInsets.zero,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(1),
          ],
          onChanged: (value) {
            if (value.isNotEmpty && index < 5) {
              FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
            } else if (value.isNotEmpty && index == 5) {
              _focusNodes[index].unfocus();
            }
            if (_otpCode.length == 6) _verify();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maskedEmail = _maskEmail(widget.email);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.iconTheme.color),
          onPressed: () => context.go(AppRoutes.login),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              Icon(Icons.mark_email_read_outlined,
                  size: 72, color: Colors.indigo.shade600),
              const SizedBox(height: 24),
              Text(
                'Verify Your Email',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'We sent a 6-digit verification code to',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                maskedEmail,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 36),
              LayoutBuilder(
                builder: (context, constraints) {
                  final fieldSize = ((constraints.maxWidth - 5 * 8) / 6)
                      .clamp(40.0, 58.0);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      6,
                      (index) => _buildOtpField(index, fieldSize),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade700,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Verify Email',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive the code? ",
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (!_canResend)
                    Text(
                      'Resend in ${_resendSeconds}s',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade500,
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: _resend,
                      child: Text(
                        _isResending ? 'Sending...' : 'Resend Code',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.indigo.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final clipboard = await Clipboard.getData('text/plain');
                  if (!mounted) return;
                  final text = clipboard?.text?.trim() ?? '';
                  if (text.length == 6 && int.tryParse(text) != null) {
                    final digits = text.split('');
                    for (int i = 0; i < 6; i++) {
                      _controllers[i].text = digits[i];
                    }
                    _verify();
                  } else {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('No valid 6-digit code in clipboard'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.content_paste, size: 18),
                label: const Text('Paste from clipboard'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.indigo.shade600,
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return email;
    return '${name[0]}${'*' * (name.length - 2)}${name[name.length - 1]}@$domain';
  }
}
