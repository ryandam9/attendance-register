import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helpers/route_helper.dart';
import '../models/office_location.dart';
import '../providers/office_provider.dart';
import '../services/location_service.dart';
import '../widgets/responsive_body.dart';
import 'permission_setup_screen.dart';

class SetupScreen extends ConsumerStatefulWidget {
  /// Pass an existing office to edit it; null means add new.
  final OfficeLocation? office;
  const SetupScreen({super.key, this.office});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  double _radius = 200;
  double? _lat;
  double? _lng;
  String? _country;
  String? _state;
  bool _busy = false;

  bool get _isEditing => widget.office != null;

  @override
  void initState() {
    super.initState();
    final o = widget.office;
    _nameCtrl = TextEditingController(text: o?.name ?? '');
    _addressCtrl = TextEditingController(text: o?.address ?? '');
    _radius = o?.radius ?? 200;
    _lat = o?.latitude;
    _lng = o?.longitude;
    _country = o?.country;
    _state = o?.state;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _busy = true);
    final pos = await LocationService.instance.getCurrentPosition();
    if (!mounted) return;

    if (pos == null) {
      _showSnack('Could not get location. Please check permissions.');
      setState(() => _busy = false);
      return;
    }

    final place = await LocationService.instance.placeFromCoordinates(
      pos.latitude,
      pos.longitude,
    );
    if (!mounted) return;
    setState(() {
      _lat = pos.latitude;
      _lng = pos.longitude;
      if (place?.address != null) _addressCtrl.text = place!.address!;
      _country = place?.country;
      _state = place?.state;
      _busy = false;
    });
  }

  Future<void> _lookupAddress() async {
    final addr = _addressCtrl.text.trim();
    if (addr.isEmpty) return;
    setState(() => _busy = true);

    final locations = await LocationService.instance.coordinatesFromAddress(addr);
    if (!mounted) return;
    if (locations == null || locations.isEmpty) {
      setState(() => _busy = false);
      _showSnack('Address not found. Try a more specific address.');
      return;
    }

    final lat = locations.first.latitude;
    final lng = locations.first.longitude;
    // Reverse-geocode the resolved point to capture the state/country used for
    // public-holiday matching.
    final place = await LocationService.instance.placeFromCoordinates(lat, lng);
    if (!mounted) return;

    setState(() {
      _lat = lat;
      _lng = lng;
      _country = place?.country;
      _state = place?.state;
      _busy = false;
    });
    _showSnack(
      'Location resolved: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);

    final office = OfficeLocation(
      id: widget.office?.id,
      name: _nameCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      // Location is optional: an office without coordinates is manual-only (no
      // geofencing / auto check-in). 0,0 marks "no location".
      latitude: _lat ?? 0.0,
      longitude: _lng ?? 0.0,
      radius: _radius,
      country: _country,
      state: _state,
    );

    final notifier = ref.read(officeProvider.notifier);
    // Whether this save creates the user's very first office — checked before
    // the insert changes the answer.
    final isFirstOffice = !_isEditing && !ref.read(officeProvider).hasOffice;
    if (_isEditing) {
      await notifier.updateOffice(office);
    } else {
      await notifier.addOffice(office);
    }

    if (mounted) {
      setState(() => _busy = false);
      if (isFirstOffice) {
        // First office registered — walk through the permissions auto check-in
        // needs, instead of leaving them silently ungranted.
        Navigator.pushReplacement(
          context,
          appRoute(const PermissionSetupScreen()),
        );
      } else {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Office' : 'Add Office')),
      body: ResponsiveBody(
        child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Name
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Office Name *',
                hintText: 'e.g. HQ, Downtown Office',
                prefixIcon: Icon(Icons.business_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter an office name' : null,
            ),
            const SizedBox(height: 16),

            // Address
            TextFormField(
              controller: _addressCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Office Address (optional)',
                hintText: 'Only needed for automatic check-in',
                helperText: 'Leave blank for a manual-only office',
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Search address',
                      icon: const Icon(Icons.search),
                      onPressed: _busy ? null : _lookupAddress,
                    ),
                    IconButton(
                      tooltip: 'Use my current location',
                      icon: const Icon(Icons.my_location),
                      onPressed: _busy ? null : _useCurrentLocation,
                    ),
                  ],
                ),
              ),
            ),

            if (_busy) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],

            if (_lat != null) ...[
              const SizedBox(height: 6),
              Text(
                'Resolved: ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              if (_state != null || _country != null)
                Text(
                  'Region: ${[_state, _country].where((s) => s != null && s.isNotEmpty).join(', ')}'
                  ' — public holidays for this region are highlighted automatically.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],

            const SizedBox(height: 28),

            // Radius slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Detection Radius',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Chip(label: Text('${_radius.toInt()} m')),
              ],
            ),
            Text(
              'Attendance is recorded when you are within this distance from the office.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            Slider(
              value: _radius,
              min: 50,
              max: 500,
              divisions: 9,
              label: '${_radius.toInt()} m',
              onChanged: (v) => setState(() => _radius = v),
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('50 m', style: TextStyle(fontSize: 12)),
                Text('500 m', style: TextStyle(fontSize: 12)),
              ],
            ),

            const SizedBox(height: 32),

            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Save Changes' : 'Add Office'),
            ),
          ],
        ),
      )),
    );
  }
}
