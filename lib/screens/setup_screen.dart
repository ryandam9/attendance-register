import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helpers/route_helper.dart';
import '../models/office_location.dart';
import '../providers/office_provider.dart';
import '../services/location_service.dart';
import '../services/wifi_service.dart';
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
  late final TextEditingController _wifiCtrl;
  double _radius = 200;
  double? _lat;
  double? _lng;
  String? _country;
  String? _state;
  late List<String> _wifiNames;
  bool _busy = false;

  bool get _isEditing => widget.office != null;

  @override
  void initState() {
    super.initState();
    final o = widget.office;
    _nameCtrl = TextEditingController(text: o?.name ?? '');
    _addressCtrl = TextEditingController(text: o?.address ?? '');
    _wifiCtrl = TextEditingController();
    _radius = o?.radius ?? 200;
    _lat = o?.latitude;
    _lng = o?.longitude;
    _country = o?.country;
    _state = o?.state;
    _wifiNames = List.of(o?.wifiNames ?? const []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _wifiCtrl.dispose();
    super.dispose();
  }

  /// Adds [name] to the Wi-Fi list if non-empty and not already present
  /// (case-insensitive), then clears the input.
  void _addWifi(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final exists =
        _wifiNames.any((w) => w.toLowerCase() == trimmed.toLowerCase());
    setState(() {
      if (!exists) _wifiNames.add(trimmed);
      _wifiCtrl.clear();
    });
  }

  Future<void> _pickFromAvailableNetworks() async {
    setState(() => _busy = true);
    final ssids = await WifiService.instance.nearbySsids();
    if (!mounted) return;
    setState(() => _busy = false);

    if (ssids.isEmpty) {
      _showSnack(
        'No Wi-Fi networks available. Turn Wi-Fi on, grant location '
        'permission, and make sure location services are enabled — or just '
        'type the network name below.',
      );
      return;
    }

    final pick = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              dense: true,
              title: Text('Available networks'),
              subtitle: Text('Tap one to add it as an office network'),
            ),
            for (final ssid in ssids)
              ListTile(
                leading: const Icon(Icons.wifi),
                title: Text(ssid),
                trailing: _wifiNames
                        .any((w) => w.toLowerCase() == ssid.toLowerCase())
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(ctx, ssid),
              ),
          ],
        ),
      ),
    );
    if (pick != null && mounted) _addWifi(pick);
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
    if (_lat == null || _lng == null) {
      _showSnack(
        'Please resolve the office location using the search or current-location buttons.',
      );
      return;
    }

    setState(() => _busy = true);

    final office = OfficeLocation(
      id: widget.office?.id,
      name: _nameCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      latitude: _lat!,
      longitude: _lng!,
      radius: _radius,
      country: _country,
      state: _state,
      wifiNames: _wifiNames,
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
      body: Form(
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
                labelText: 'Office Address *',
                hintText: 'Type an address or use the buttons →',
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
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter an address' : null,
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

            // ── Wi-Fi networks ──────────────────────────────────────────────
            Text(
              'Office Wi-Fi Networks',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'A second way to record attendance: when any of these networks '
              'is in range — even if you stay on mobile data and never connect '
              '— the day is marked, no GPS needed. Optional. (Android only.)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            if (_wifiNames.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final name in _wifiNames)
                    InputChip(
                      avatar: const Icon(Icons.wifi, size: 18),
                      label: Text(name),
                      onDeleted: () => setState(() => _wifiNames.remove(name)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _wifiCtrl,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Wi-Fi network name (SSID)',
                hintText: 'e.g. Office-WiFi, Office-Guest',
                prefixIcon: const Icon(Icons.wifi_outlined),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Add',
                  icon: const Icon(Icons.add),
                  onPressed: () => _addWifi(_wifiCtrl.text),
                ),
              ),
              onSubmitted: _addWifi,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _busy ? null : _pickFromAvailableNetworks,
                icon: const Icon(Icons.wifi_find),
                label: const Text('Pick from available networks'),
              ),
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
      ),
    );
  }
}
