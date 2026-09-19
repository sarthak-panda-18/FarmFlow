import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../services/api_service.dart';

/// Modal dialog allowing runtime configuration and testing of backend API Server URL
class ServerConfigDialog extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback? onSaved;

  const ServerConfigDialog({
    super.key,
    required this.apiService,
    this.onSaved,
  });

  static Future<void> show(BuildContext context, ApiService apiService, {VoidCallback? onSaved}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ServerConfigDialog(
        apiService: apiService,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends State<ServerConfigDialog> {
  late final TextEditingController _urlController;
  bool _isTesting = false;
  bool _isAutoDetecting = false;
  Map<String, dynamic>? _testResult;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.apiService.baseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _runConnectionTest([String? specificUrl]) async {
    final target = specificUrl ?? _urlController.text.trim();
    if (target.isEmpty) return;

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final result = await widget.apiService.testConnection(target);

    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _testResult = result;
    });
  }

  Future<void> _runAutoDetect() async {
    setState(() {
      _isAutoDetecting = true;
      _testResult = null;
    });

    final detected = await widget.apiService.autoDetectServer();

    if (!mounted) return;
    setState(() {
      _isAutoDetecting = false;
    });

    if (detected != null) {
      _urlController.text = detected;
      await _runConnectionTest(detected);
    } else {
      setState(() {
        _testResult = {
          'success': false,
          'message': 'No reachable backend found on USB (127.0.0.1), LAN (10.1.36.198), or Emulator (10.0.2.2). Ensure "npm run dev" is running on PC.',
        };
      });
    }
  }

  void _saveAndApply() {
    final newUrl = _urlController.text.trim();
    if (newUrl.isEmpty) return;

    widget.apiService.updateBaseUrl(newUrl);
    widget.onSaved?.call();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Server URL set to: ${AppConfig.apiBaseUrl}'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.settings_ethernet, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Server Connection',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select a preset or enter the IP address of your computer running the backend server:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),

            // Preset Quick Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPresetChip(
                  label: '⚡ USB (ADB Reverse)',
                  url: AppConfig.defaultUsbUrl,
                  tooltip: 'Use when phone is connected via USB cable with adb reverse',
                ),
                _buildPresetChip(
                  label: '📶 Wi-Fi / LAN IP',
                  url: AppConfig.defaultLanUrl,
                  tooltip: 'Use when phone and PC are on the same Wi-Fi / Hotspot',
                ),
                _buildPresetChip(
                  label: '💻 Emulator',
                  url: AppConfig.defaultEmulatorUrl,
                  tooltip: 'Android Studio Emulator loopback',
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Server URL Input
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Backend API URL',
                hintText: 'http://<your-pc-ip>:5000/api',
                prefixIcon: const Icon(Icons.link, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => _urlController.clear(),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 12),

            // Auto-Detect & Test Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_isTesting || _isAutoDetecting) ? null : _runAutoDetect,
                    icon: _isAutoDetecting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.radar, size: 16),
                    label: const Text('Auto-Detect', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_isTesting || _isAutoDetecting) ? null : () => _runConnectionTest(),
                    icon: _isTesting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.network_ping, size: 16),
                    label: const Text('Test Ping', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),

            // Test Result Feedback Banner
            if (_testResult != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _testResult!['success'] == true
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _testResult!['success'] == true ? AppColors.success : AppColors.error,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _testResult!['success'] == true ? Icons.check_circle : Icons.error,
                      color: _testResult!['success'] == true ? AppColors.success : AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _testResult!['success'] == true ? 'Connected Successfully!' : 'Connection Failed',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _testResult!['success'] == true ? AppColors.success : AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (_testResult!['latencyMs'] != null)
                            Text(
                              'Ping: ${_testResult!['latencyMs']}ms | Database: ${_testResult!['database']}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          if (_testResult!['message'] != null)
                            Text(
                              _testResult!['message'].toString(),
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                '💡 Tip: If using USB cable, select "USB (ADB Reverse)". If using Wi-Fi, ensure your phone and PC are connected to the same Wi-Fi router / hotspot.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveAndApply,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Save & Apply'),
        ),
      ],
    );
  }

  Widget _buildPresetChip({
    required String label,
    required String url,
    required String tooltip,
  }) {
    final isSelected = _urlController.text.trim() == url;
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      tooltip: tooltip,
      backgroundColor: isSelected ? AppColors.primary.withValues(alpha: 0.15) : null,
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.border,
        width: isSelected ? 1.5 : 1.0,
      ),
      onPressed: () {
        setState(() {
          _urlController.text = url;
          _testResult = null;
        });
      },
    );
  }
}
