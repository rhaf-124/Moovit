import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OTPVerificationPage extends StatefulWidget {
  final String phoneNumber;
  const OTPVerificationPage({super.key, required this.phoneNumber});

  @override
  State<OTPVerificationPage> createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  late List<FocusNode> _rawListenerFocusNodes; // for RawKeyboardListener
  bool _isLoading = false;
  int _resendSeconds = 30;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(6, (_) => TextEditingController());
    _focusNodes = List.generate(6, (_) => FocusNode());
    _rawListenerFocusNodes = List.generate(6, (_) => FocusNode());
    _startResendTimer();
    // Auto-focus first field after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNodes[0]);
    });
  }

  void _startResendTimer() {
    _canResend = false;
    _resendSeconds = 30;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      if (_resendSeconds == 1) {
        setState(() => _canResend = true);
        return false;
      }
      setState(() => _resendSeconds--);
      return true;
    });
  }

  @override
  void dispose() {
    for (var c in _controllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    for (var f in _rawListenerFocusNodes) f.dispose();
    super.dispose();
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  void _onOtpComplete() {
    if (_otpCode.length == 6) {
      _verifyOTP();
    }
  }

  Future<void> _verifyOTP() async {
    if (_otpCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the full 6-digit code')),
      );
      return;
    }
    setState(() => _isLoading = true);
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _isLoading = false);
      // TODO: Replace with actual verification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verifying OTP: $_otpCode')),
      );
    }
  }

  Future<void> _resendCode() async {
    if (!_canResend) return;
    // TODO: Implement actual resend logic
    _startResendTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OTP resent successfully')),
    );
  }

  Widget _buildOtpField(int index) {
    return SizedBox(
      width: 56,
      height: 70,
      child: RawKeyboardListener(
        focusNode: _rawListenerFocusNodes[index],
        onKey: (event) {
          if (event is RawKeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace) {
            // If current field is empty → go back and clear previous
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
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey.shade800
                : Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade700
                    : Colors.grey.shade300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor,
                width: 2,
              ),
            ),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(1),
          ],
          onChanged: (value) {
            if (value.isNotEmpty) {
              if (index < 5) {
                FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
              } else {
                _focusNodes[index].unfocus();
              }
            }
            if (_otpCode.length == 6) _onOtpComplete();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(  // ← Prevents bottom overflow when keyboard opens
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 20 : 32,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Header
              Icon(
                Icons.sms_outlined,
                size: 72,
                color: theme.primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                "Verification Code",
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "We sent a 6-digit code to",
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 4),
              // Phone number with edit icon
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.phoneNumber,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.edit,
                      size: 18,
                      color: theme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              // OTP Fields
              SizedBox(
                width: isSmallScreen ? double.infinity : 400,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (index) => _buildOtpField(index)),
                ),
              ),
              const SizedBox(height: 48),
              // Verify Button
              SizedBox(
                width: isSmallScreen ? double.infinity : 280,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
                          "Verify & Continue",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              // Resend Section
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive the code? ",
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (!_canResend)
                    Text(
                      "Resend in $_resendSeconds s",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  if (_canResend)
                    GestureDetector(
                      onTap: _resendCode,
                      child: Text(
                        "Resend Code",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Paste from clipboard option (always visible for convenience)
              TextButton.icon(
                onPressed: () async {
                  final clipboard = await Clipboard.getData('text/plain');
                  if (clipboard?.text != null &&
                      clipboard!.text!.length == 6 &&
                      int.tryParse(clipboard.text!) != null) {
                    final digits = clipboard.text!.split('');
                    for (int i = 0; i < digits.length; i++) {
                      _controllers[i].text = digits[i];
                    }
                    _onOtpComplete();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invalid OTP in clipboard')),
                    );
                  }
                },
                icon: const Icon(Icons.content_paste, size: 18),
                label: const Text("Paste from clipboard"),
                style: TextButton.styleFrom(
                  foregroundColor: theme.primaryColor,
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
