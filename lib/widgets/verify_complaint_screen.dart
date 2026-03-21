import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/complaint_store.dart';
import '../services/flask_ai_service.dart';
import '../services/storage_service.dart';

const Color _primary = Color(0xFF4A5D6B);
const Color _surface = Color(0xFFE7E2D8);
const Color _textPrimary = Color(0xFF2B2B2B);
const Color _textSecondary = Color(0xFF6F6F6F);
const Color _background = Color(0xFFF6F4EF);

class VerifyComplaintScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final List<String> contractors;
  final List<String> workGangs;
  final VoidCallback onVerified;

  const VerifyComplaintScreen({
    super.key,
    required this.data,
    required this.contractors,
    required this.workGangs,
    required this.onVerified,
  });

  @override
  State<VerifyComplaintScreen> createState() => _VerifyComplaintScreenState();
}

class _VerifyComplaintScreenState extends State<VerifyComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _remarksController = TextEditingController();
  final _rootCauseController = TextEditingController();
  final _estimatedCostController = TextEditingController();
  final _estimatedDurationController = TextEditingController();
  final _manpowerController = TextEditingController();
  final _materialsController = TextEditingController();
  final List<String> _fieldPhotos = [];
  String? _selectedContractor;
  String? _selectedWorkGang;
  String? _selectedDamageExtent;
  String? _selectedRiskLevel;
  String? _selectedTrafficImpact;
  String? _selectedRecommendedAction;
  bool _isSubmitting = false;
  final ImagePicker _picker = ImagePicker();

  static const List<String> _damageExtentOptions = <String>[
    'Minor (localized patch)',
    'Moderate (lane-level repair)',
    'Severe (full stretch restoration)',
  ];
  static const List<String> _riskLevelOptions = <String>[
    'Low',
    'Medium',
    'High',
    'Critical',
  ];
  static const List<String> _trafficImpactOptions = <String>[
    'Low impact',
    'Moderate congestion',
    'Heavy congestion',
    'Traffic diversion needed',
  ];
  static const List<String> _actionOptions = <String>[
    'Pothole patching',
    'Surface relaying',
    'Drainage correction',
    'Structural repair',
    'Temporary safety mitigation',
  ];

  @override
  void initState() {
    super.initState();
    final assignedType = (widget.data['assignedPartyType'] ?? '').toString();
    final assignedTo = widget.data['assignedTo']?.toString();
    if (assignedType == 'Contractor') {
      _selectedContractor = _resolveInitialSelection(
        assignedTo,
        widget.contractors,
      );
    } else if (assignedType == 'Work Gang') {
      _selectedWorkGang = _resolveInitialSelection(
        assignedTo,
        widget.workGangs,
      );
    }
  }

  Future<void> _pickPhotos() async {
    final images = await _picker.pickMultiImage();
    if (images.isEmpty) return;
    setState(() {
      for (final image in images) {
        if (_fieldPhotos.length < 10) _fieldPhotos.add(image.path);
      }
    });
  }

  Future<void> _takePhoto() async {
    final photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;
    setState(() {
      if (_fieldPhotos.length < 10) _fieldPhotos.add(photo.path);
    });
  }

  Future<void> _submitVerify() async {
    if (_fieldPhotos.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least 2 field visit photos'),
          backgroundColor: Color(0xFFC75D5D),
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_selectedContractor == null && _selectedWorkGang == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assign Contractor or Work Gang'),
          backgroundColor: Color(0xFFC75D5D),
        ),
      );
      return;
    }

    if (_selectedDamageExtent == null ||
        _selectedRiskLevel == null ||
        _selectedTrafficImpact == null ||
        _selectedRecommendedAction == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select all verification framework fields'),
          backgroundColor: Color(0xFFC75D5D),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final existingImages =
          (widget.data['images'] as List<dynamic>?)?.cast<String>() ?? [];
      final beforeImages =
          (widget.data['beforeImages'] as List<dynamic>?)?.cast<String>() ??
          existingImages;
      final uploadedFieldPhotos = await StorageService.instance
          .uploadComplaintImages(
            localPaths: _fieldPhotos,
            folder: 'verification',
          );
      final allImages = [...existingImages, ...uploadedFieldPhotos];
      final afterImages = [...uploadedFieldPhotos];

      Map<String, dynamic>? verificationResult;
      try {
        final beforeForSsim = beforeImages.isNotEmpty
            ? beforeImages.first
            : (existingImages.isNotEmpty ? existingImages.first : null);
        final afterForSsim = uploadedFieldPhotos.isNotEmpty
            ? uploadedFieldPhotos.first
            : null;
        if (beforeForSsim != null && afterForSsim != null) {
          verificationResult = await FlaskAiService.verifyRepair(
            beforeImage: beforeForSsim,
            afterImage: afterForSsim,
            complaintId: widget.data['id'] as String,
          );
        }
      } on TimeoutException {
        // FIX 4: Verification server timed out — must not proceed
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Verification server timed out. '
              'Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSubmitting = false);
        return; // do NOT proceed with status update
      } catch (e) {
        // FIX 4: Verification failed — must not proceed
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Verification failed: $e. '
              'Cannot mark as resolved without '
              'AI verification.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isSubmitting = false);
        return; // do NOT proceed with status update
      }

      final verdict = verificationResult?['verdict']?.toString();
      final isRepairVerified = verdict == 'REPAIR_VERIFIED';

      await ComplaintStore.instance
          .submitForCEAuthorization(widget.data['id'] as String, {
            'verifiedDate': DateTime.now(),
            'lastUpdate': DateTime.now(),
            'officialRemarks': _remarksController.text.trim(),
            'assignedTo': _selectedContractor ?? _selectedWorkGang,
            'assignedPartyType': _selectedContractor != null
                ? 'Contractor'
                : 'Work Gang',
            'workGang': _selectedWorkGang,
            'images': allImages,
            'beforeImages': beforeImages,
            'afterImages': afterImages,
            if (verificationResult?['ssim_score'] != null)
              'ssimScore': verificationResult?['ssim_score'],
            if (verificationResult?['verification_hash'] != null)
              'verificationHash': verificationResult?['verification_hash'],
            if (verdict != null) 'verificationStatus': verdict,
            if (isRepairVerified) 'status': 'PendingCEApproval',
          });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Submitted for City Engineer final authorization'),
          backgroundColor: Color(0xFF7DB89A),
        ),
      );
      widget.onVerified();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _remarksController.dispose();
    _rootCauseController.dispose();
    _estimatedCostController.dispose();
    _estimatedDurationController.dispose();
    _manpowerController.dispose();
    _materialsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 1,
        title: const Text(
          'Verify',
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.data['title'] ?? 'Complaint',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.data['location'] ?? '',
              style: const TextStyle(fontSize: 13, color: _textSecondary),
            ),
            const SizedBox(height: 24),
            const Text(
              'Field Visit Photos',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...List.generate(
                  _fieldPhotos.length,
                  (i) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_fieldPhotos[i]),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: -6,
                        right: -6,
                        child: GestureDetector(
                          onTap: () => setState(() => _fieldPhotos.removeAt(i)),
                          child: const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.red,
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _photoActionTile(
                  Icons.add_photo_alternate_outlined,
                  'Add',
                  _pickPhotos,
                ),
                _photoActionTile(
                  Icons.camera_alt_outlined,
                  'Camera',
                  _takePhoto,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Verification Framework',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedDamageExtent,
              decoration: _inputDecoration(),
              hint: const Text('Damage extent'),
              items: _damageExtentOptions
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _selectedDamageExtent = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedRiskLevel,
              decoration: _inputDecoration(),
              hint: const Text('Safety risk level'),
              items: _riskLevelOptions
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedRiskLevel = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedTrafficImpact,
              decoration: _inputDecoration(),
              hint: const Text('Traffic impact'),
              items: _trafficImpactOptions
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _selectedTrafficImpact = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedRecommendedAction,
              decoration: _inputDecoration(),
              hint: const Text('Recommended action'),
              items: _actionOptions
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _selectedRecommendedAction = value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _estimatedCostController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration(hint: 'Estimated cost (INR)'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _estimatedDurationController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration(hint: 'Estimated completion days'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _manpowerController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration(hint: 'Required manpower count'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _materialsController,
              maxLines: 2,
              decoration: _inputDecoration(hint: 'Materials required'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _rootCauseController,
              maxLines: 2,
              decoration: _inputDecoration(hint: 'Root cause analysis'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            const Text(
              'Official Remarks',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _remarksController,
              maxLines: 4,
              decoration: _inputDecoration(
                hint: 'Describe field inspection findings...',
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            const Text(
              'Assign Contractor or Work Gang',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedContractor,
              decoration: _inputDecoration(),
              hint: const Text('Select contractor'),
              items: _uniqueStrings(widget.contractors)
                  .map(
                    (contractor) => DropdownMenuItem(
                      value: contractor,
                      child: Text(contractor),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                _selectedContractor = value;
                if (value != null) _selectedWorkGang = null;
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedWorkGang,
              decoration: _inputDecoration(),
              hint: const Text('Select work gang'),
              items: _uniqueStrings(widget.workGangs)
                  .map(
                    (gang) => DropdownMenuItem(value: gang, child: Text(gang)),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                _selectedWorkGang = value;
                if (value != null) _selectedContractor = null;
              }),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitVerify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7DB89A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Verify',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoActionTile(
    IconData icon,
    String label,
    Future<void> Function() onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _primary.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _primary, size: 28),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: _primary)),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: _surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  List<String> _uniqueStrings(List<String> items) {
    final seen = <String>{};
    final result = <String>[];
    for (final item in items) {
      final normalized = item.trim().toLowerCase();
      if (normalized.isEmpty || seen.contains(normalized)) continue;
      seen.add(normalized);
      result.add(item);
    }
    return result;
  }

  String? _resolveInitialSelection(String? rawValue, List<String> options) {
    if (rawValue == null || rawValue.trim().isEmpty) return null;
    final value = rawValue.trim().toLowerCase();
    final uniqueOptions = _uniqueStrings(options);

    for (final option in uniqueOptions) {
      if (option.trim().toLowerCase() == value) return option;
    }

    final partialMatches = uniqueOptions.where((option) {
      final o = option.toLowerCase();
      return o.contains(value) || value.contains(o);
    }).toList();

    return partialMatches.length == 1 ? partialMatches.first : null;
  }
}
