import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/repositories/driver_repository.dart';
import '../models/scan_result_model.dart';

class DriverScanPage extends StatefulWidget {
  const DriverScanPage({super.key});

  @override
  State<DriverScanPage> createState() => _DriverScanPageState();
}

class _DriverScanPageState extends State<DriverScanPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _laserController;
  late MobileScannerController _scannerController;
  final TextEditingController _manualCodeController = TextEditingController();

  bool _isFlashOn = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _laserController.dispose();
    _scannerController.dispose();
    _manualCodeController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue != null) {
      _handleCode(barcode!.rawValue!);
    }
  }

  Future<void> _handleCode(String code) async {
    if (_isProcessing || !mounted) return;
    setState(() => _isProcessing = true);
    final repo = RepositoryProvider.of<DriverRepository>(context);
    await _scannerController.stop();

    try {
      final result = await repo.scanTicket(code: code);
      if (mounted) _showSuccessDialog(result);
    } catch (e) {
      if (mounted) _showErrorDialog(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('already') || msg.contains('boarded')) {
      return 'This ticket has already been scanned.';
    }
    if (msg.contains('not found') || msg.contains('invalid')) {
      return 'Invalid ticket code. Please try again.';
    }
    if (msg.contains('expired') || msg.contains('cancelled')) {
      return 'This ticket is expired or cancelled.';
    }
    if (msg.contains('connection') || msg.contains('network')) {
      return 'No connection. Check your internet and try again.';
    }
    return 'Could not verify ticket. Please try again.';
  }

  void _showSuccessDialog(ScanResultModel result) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    String timeStr = 'Just now';
    if (result.boardedAt != null) {
      final t = result.boardedAt!.toLocal();
      timeStr = '${t.day} ${months[t.month - 1]}  '
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 16,
        backgroundColor: isDark ? const Color(0xFF162238) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 56,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Ticket Validated!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              if (result.seatNumber.isNotEmpty)
                Text(
                  'Seat ${result.seatNumber}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 14),
              _buildDialogInfoRow('Passenger', result.passengerName),
              const SizedBox(height: 8),
              if (result.seatNumber.isNotEmpty) ...[
                _buildDialogInfoRow('Seat', result.seatNumber),
                const SizedBox(height: 8),
              ],
              _buildDialogInfoRow('Scanned At', timeStr),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _scannerController.start();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Ready for Next Scan',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 16,
        backgroundColor: isDark ? const Color(0xFF162238) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cancel_rounded,
                  color: AppColors.error,
                  size: 56,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Scan Failed',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _scannerController.start();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showManualEntryDialog() {
    _manualCodeController.clear();

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: isDark ? const Color(0xFF162238) : Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.keyboard_rounded,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Enter Ticket Code',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ]),
                const SizedBox(height: 20),
                TextField(
                  controller: _manualCodeController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-Z0-9\-]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Booking ID or Ticket Code',
                    hintText: 'e.g. A1B2C3D4',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.confirmation_number_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the 8-character booking reference or full ID',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          final code = _manualCodeController.text.trim();
                          if (code.isEmpty) return;
                          Navigator.pop(ctx);
                          _handleCode(code);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'Verify',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogInfoRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white54 : Colors.black38,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final scanAreaSize = size.width * 0.68;

    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      appBar: AppBar(
        title: const Text(
          'Scan Tickets',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // ── Real camera feed ────────────────────────────────────────────
          Positioned.fill(
            child: MobileScanner(
              controller: _scannerController,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) {
                return Container(
                  color: const Color(0xFF070B19),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_off_rounded,
                          color: Colors.white30, size: 64),
                      const SizedBox(height: 12),
                      Text(
                        'Camera unavailable\n${error.errorDetails?.message ?? ''}',
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // ── Dark vignette overlay with transparent scan viewport ─────────
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.72),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(color: Colors.transparent),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      height: scanAreaSize,
                      width: scanAreaSize,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Scan frame corners + laser + processing indicator ─────────────
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: scanAreaSize,
              height: scanAreaSize,
              child: Stack(
                children: [
                  if (!_isProcessing)
                    AnimatedBuilder(
                      animation: _laserController,
                      builder: (context, child) {
                        return Positioned(
                          top: _laserController.value * (scanAreaSize - 4),
                          left: 12,
                          right: 12,
                          child: Container(
                            height: 3.5,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.8),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  _buildScanCorner(top: 0, left: 0, border: const Border(top: BorderSide(color: AppColors.primary, width: 4), left: BorderSide(color: AppColors.primary, width: 4))),
                  _buildScanCorner(top: 0, right: 0, border: const Border(top: BorderSide(color: AppColors.primary, width: 4), right: BorderSide(color: AppColors.primary, width: 4))),
                  _buildScanCorner(bottom: 0, left: 0, border: const Border(bottom: BorderSide(color: AppColors.primary, width: 4), left: BorderSide(color: AppColors.primary, width: 4))),
                  _buildScanCorner(bottom: 0, right: 0, border: const Border(bottom: BorderSide(color: AppColors.primary, width: 4), right: BorderSide(color: AppColors.primary, width: 4))),

                  if (_isProcessing)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 3.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Bottom controls ────────────────────────────────────────────────
          Positioned(
            left: 24,
            right: 24,
            bottom: size.height * 0.08,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isProcessing
                      ? 'Verifying Ticket...'
                      : 'Align ticket QR code within the frame',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: _isFlashOn
                          ? Icons.flash_on_rounded
                          : Icons.flash_off_rounded,
                      label: 'Flashlight',
                      onPressed: () async {
                        await _scannerController.toggleTorch();
                        setState(() => _isFlashOn = !_isFlashOn);
                      },
                    ),
                    _buildActionButton(
                      icon: Icons.qr_code_rounded,
                      label: 'Scan QR',
                      color: AppColors.primary,
                      onPressed: _isProcessing ? null : () {},
                    ),
                    _buildActionButton(
                      icon: Icons.keyboard_rounded,
                      label: 'Enter Code',
                      onPressed: _isProcessing
                          ? null
                          : () {
                              _scannerController.stop();
                              _showManualEntryDialog();
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanCorner({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required BoxBorder border,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(border: border),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: onPressed == null
                ? Colors.white10
                : color ?? Colors.white10,
            foregroundColor: onPressed == null ? Colors.white30 : Colors.white,
            padding: const EdgeInsets.all(16),
            shape: const CircleBorder(),
          ),
          icon: Icon(icon, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: onPressed == null ? Colors.white30 : Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
