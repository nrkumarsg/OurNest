import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';

class LocationShareSheet extends StatefulWidget {
  final ValueChanged<String> onSendLocationMessage;

  const LocationShareSheet({
    super.key,
    required this.onSendLocationMessage,
  });

  @override
  State<LocationShareSheet> createState() => _LocationShareSheetState();
}

class _LocationShareSheetState extends State<LocationShareSheet> {
  final TextEditingController _noteCtrl = TextEditingController();
  bool _isLoadingGps = true;
  String? _errorText;
  Position? _position;
  String _selectedMode = 'current'; // 'current' | 'live_15m' | 'live_1h' | 'live_8h'

  static const List<String> _landmarkPresets = [
    '🏠 Reached Home Safely ❤️',
    '🚗 On my way home now',
    '🏫 At School / College',
    '🏢 At Office / Workplace',
    '🏥 At Clinic / Hospital',
    '🛒 At Market / Shopping',
  ];

  @override
  void initState() {
    super.initState();
    _acquireGpsPosition();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _acquireGpsPosition() async {
    setState(() {
      _isLoadingGps = true;
      _errorText = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoadingGps = false;
          _errorText =
              'Phone GPS / Location Service is turned off. Please enable Location on your phone or tap Retry.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoadingGps = false;
            _errorText =
                'Location permission was denied. Please allow Location access to share your live GPS pin.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoadingGps = false;
          _errorText =
              'Location permission is permanently disabled in phone Settings. Tap "Open Settings" to allow.';
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      if (mounted) {
        setState(() {
          _position = pos;
          _isLoadingGps = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingGps = false;
          _errorText =
              'Could not lock onto GPS signal indoors. You can retry or send a landmark check-in.';
        });
      }
    }
  }

  void _shareNow() {
    final note = _noteCtrl.text.trim();
    final modeLabel = _selectedMode == 'live_15m'
        ? '🛰️ LIVE LOCATION (Active for 15 Mins)'
        : _selectedMode == 'live_1h'
            ? '🛰️ LIVE LOCATION (Active for 1 Hour)'
            : _selectedMode == 'live_8h'
                ? '🛰️ LIVE LOCATION (Active for 8 Hours)'
                : '📍 CURRENT GPS LOCATION';

    if (_position != null) {
      final lat = _position!.latitude.toStringAsFixed(6);
      final lng = _position!.longitude.toStringAsFixed(6);
      final acc = _position!.accuracy.toStringAsFixed(0);
      final mapsUrl =
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

      final msg = StringBuffer()
        ..writeln(modeLabel)
        ..writeln(note.isNotEmpty ? note : 'Shared my exact family GPS pin')
        ..writeln('🧭 Coordinates: $lat, $lng (±${acc}m)')
        ..write('🗺️ Open Map: $mapsUrl');

      widget.onSendLocationMessage(msg.toString());
    } else {
      final fallbackQuery = Uri.encodeComponent(
          note.isNotEmpty ? note : 'My Current Location');
      final mapsUrl =
          'https://www.google.com/maps/search/?api=1&query=$fallbackQuery';
      final msg = StringBuffer()
        ..writeln(modeLabel)
        ..writeln(note.isNotEmpty ? note : 'Shared family location check-in')
        ..write('🗺️ Open Map: $mapsUrl');

      widget.onSendLocationMessage(msg.toString());
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal.withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.my_location_rounded,
                    color: AppColors.primaryTeal,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share Live & Current Location',
                        style: GoogleFonts.nunito(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: onSurface,
                        ),
                      ),
                      Text(
                        'End-to-End Encrypted GPS Pin • Opens in Google Maps',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Live GPS Radar Status Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.primaryTeal.withOpacity(0.28),
                ),
              ),
              child: _isLoadingGps
                  ? Row(
                      children: [
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Acquiring high-accuracy satellite GPS coordinates...',
                            style: GoogleFonts.nunito(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: onSurface,
                            ),
                          ),
                        ),
                      ],
                    )
                  : (_position != null)
                      ? Row(
                          children: [
                            const Icon(Icons.gps_fixed_rounded,
                                color: AppColors.success, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'GPS Locked (±${_position!.accuracy.toStringAsFixed(0)}m accuracy)',
                                    style: GoogleFonts.nunito(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.success,
                                    ),
                                  ),
                                  Text(
                                    'Lat: ${_position!.latitude.toStringAsFixed(5)}, Lng: ${_position!.longitude.toStringAsFixed(5)}',
                                    style: GoogleFonts.nunito(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.map_rounded, size: 18),
                              label: const Text('Preview'),
                              onPressed: () {
                                final lat = _position!.latitude;
                                final lng = _position!.longitude;
                                launchUrl(
                                  Uri.parse(
                                      'https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
                                  mode: LaunchMode.externalApplication,
                                );
                              },
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _errorText ?? 'GPS unavailable',
                              style: GoogleFonts.nunito(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accentCoralDark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.refresh_rounded,
                                      size: 18),
                                  label: const Text('Retry GPS'),
                                  onPressed: _acquireGpsPosition,
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () =>
                                      Geolocator.openLocationSettings(),
                                  child: const Text('Location Settings'),
                                ),
                              ],
                            ),
                          ],
                        ),
            ),
            const SizedBox(height: 16),

            // Mode Selection: Current Pin vs Live Location Duration
            Text(
              'Choose Location Sharing Mode:',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryTeal,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildModeChip(
                  id: 'current',
                  label: '📍 Current Pin (Instant)',
                  onSurface: onSurface,
                ),
                _buildModeChip(
                  id: 'live_15m',
                  label: '🛰️ Live (15 Mins)',
                  onSurface: onSurface,
                ),
                _buildModeChip(
                  id: 'live_1h',
                  label: '🛰️ Live (1 Hour)',
                  onSurface: onSurface,
                ),
                _buildModeChip(
                  id: 'live_8h',
                  label: '🛰️ Live (8 Hours)',
                  onSurface: onSurface,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Quick Landmark / Safe Check-In Chips
            Text(
              '1-Tap Safe Arrival & Landmark Notes:',
              style: GoogleFonts.nunito(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _landmarkPresets.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final preset = _landmarkPresets[i];
                  return ActionChip(
                    label: Text(
                      preset,
                      style: GoogleFonts.nunito(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryTeal,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _noteCtrl.text = preset;
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _noteCtrl,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: onSurface,
              ),
              decoration: const InputDecoration(
                labelText: 'Optional Landmark / Note (e.g., Gate 2, Near Metro)',
                prefixIcon: Icon(Icons.place_rounded),
              ),
            ),
            const SizedBox(height: 18),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.send_rounded),
              label: Text(
                _selectedMode == 'current'
                    ? 'Send Encrypted GPS Location'
                    : 'Start Sharing Live Location',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onPressed: _shareNow,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeChip({
    required String id,
    required String label,
    required Color onSurface,
  }) {
    final isSelected = _selectedMode == id;
    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? Colors.white : onSurface,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primaryTeal,
      onSelected: (_) => setState(() => _selectedMode = id),
    );
  }
}

