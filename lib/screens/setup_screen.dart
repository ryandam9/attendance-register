import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helpers/route_helper.dart';
import '../models/office_location.dart';
import '../providers/office_provider.dart';
import '../services/location_service.dart';
import '../widgets/responsive_body.dart';
import 'permission_setup_screen.dart';

enum _TrackingMode { automatic, manual }

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
  // Editable so an office still gets a region when geocoding cannot supply one
  // — public holidays are matched on these two fields alone.
  late final TextEditingController _countryCtrl;
  late final TextEditingController _stateCtrl;
  double _radius = 200;
  double? _lat;
  double? _lng;
  late _TrackingMode _trackingMode;
  bool _busy = false;
  String? _locationError;

  bool get _isEditing => widget.office != null;

  @override
  void initState() {
    super.initState();
    final o = widget.office;
    _nameCtrl = TextEditingController(text: o?.name ?? '');
    _addressCtrl = TextEditingController(text: o?.address ?? '');
    _radius = o?.radius ?? 200;
    _lat = o?.hasLocation == true ? o!.latitude : null;
    _lng = o?.hasLocation == true ? o!.longitude : null;
    _countryCtrl = TextEditingController(text: o?.country ?? '');
    _stateCtrl = TextEditingController(text: o?.state ?? '');
    _trackingMode = o == null || o.hasLocation
        ? _TrackingMode.automatic
        : _TrackingMode.manual;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _countryCtrl.dispose();
    _stateCtrl.dispose();
    super.dispose();
  }

  /// Writes a resolved region into the fields, leaving anything the user typed
  /// in place when the geocoder came back empty — a failed lookup must not
  /// erase a region that was entered by hand.
  void _applyRegion(GeoPlace? place) {
    final country = place?.country;
    final state = place?.state;
    if (country != null && country.isNotEmpty) _countryCtrl.text = country;
    if (state != null && state.isNotEmpty) _stateCtrl.text = state;
  }

  static String? _trimmedOrNull(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  /// True when either field is empty. A holiday row is matched on the pair, so
  /// one without the other matches nothing.
  bool get _regionMissing =>
      _countryCtrl.text.trim().isEmpty || _stateCtrl.text.trim().isEmpty;

  /// Warn when a lookup resolved coordinates but no region: the office looks
  /// fully configured, yet no public holiday can ever match it.
  void _warnIfRegionMissing() {
    if (!_regionMissing) return;
    _showSnack(
      'Could not work out the country and state for this address — fill them '
      'in below so public holidays are matched.',
    );
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _busy = true;
      _locationError = null;
    });
    final pos = await LocationService.instance.getCurrentPosition();
    if (!mounted) return;

    if (pos == null) {
      setState(() {
        _busy = false;
        _locationError = noPositionMessage;
      });
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
      _applyRegion(place);
      final resolved = place?.address;
      if (resolved != null && resolved.isNotEmpty) {
        _addressCtrl.text = resolved;
      } else if (_addressCtrl.text.trim().isEmpty) {
        // Reverse geocoding can return nothing (common on macOS), which left the
        // address blank even though the position resolved. Fall back to the
        // coordinates so the field isn't empty — it's only a label; the saved
        // office uses _lat/_lng.
        _addressCtrl.text =
            '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      }
      _busy = false;
      _locationError = null;
    });
    _warnIfRegionMissing();
  }

  Future<bool> _lookupAddress() async {
    final addr = _addressCtrl.text.trim();
    if (addr.isEmpty) {
      setState(() => _locationError = 'Enter an office address first.');
      return false;
    }
    setState(() {
      _busy = true;
      _locationError = null;
    });

    final locations = await LocationService.instance.coordinatesFromAddress(
      addr,
    );
    if (!mounted) return false;
    if (locations == null || locations.isEmpty) {
      setState(() {
        _busy = false;
        _locationError =
            'Address not found. Add a suburb, state or postcode and try again.';
      });
      return false;
    }

    final lat = locations.first.latitude;
    final lng = locations.first.longitude;
    // Reverse-geocode the resolved point to capture the state/country used for
    // public-holiday matching.
    final place = await LocationService.instance.placeFromCoordinates(lat, lng);
    if (!mounted) return false;

    setState(() {
      _lat = lat;
      _lng = lng;
      _applyRegion(place);
      _busy = false;
      _locationError = null;
    });
    _showSnack(
      'Location resolved: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
    );
    _warnIfRegionMissing();
    return true;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_trackingMode == _TrackingMode.automatic && _lat == null) {
      final resolved = await _lookupAddress();
      if (!resolved || !mounted) return;
    }

    setState(() => _busy = true);

    final automatic = _trackingMode == _TrackingMode.automatic;

    final office = OfficeLocation(
      id: widget.office?.id,
      name: _nameCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      // Location is optional: an office without coordinates is manual-only (no
      // geofencing / auto check-in). 0,0 marks "no location".
      latitude: automatic ? _lat! : 0.0,
      longitude: automatic ? _lng! : 0.0,
      radius: _radius,
      // Not gated on [automatic]: the region drives public-holiday matching,
      // which has nothing to do with whether the app watches for arrivals.
      country: _trimmedOrNull(_countryCtrl.text),
      state: _trimmedOrNull(_stateCtrl.text),
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
      if (isFirstOffice && automatic) {
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
    final cs = Theme.of(context).colorScheme;
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
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter an office name'
                    : null,
              ),
              const SizedBox(height: 24),
              Text(
                'How should attendance be tracked?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<_TrackingMode>(
                segments: const [
                  ButtonSegment(
                    value: _TrackingMode.automatic,
                    icon: Icon(Icons.my_location_outlined),
                    label: Text('Automatic'),
                  ),
                  ButtonSegment(
                    value: _TrackingMode.manual,
                    icon: Icon(Icons.touch_app_outlined),
                    label: Text('Manual only'),
                  ),
                ],
                selected: {_trackingMode},
                onSelectionChanged: (selection) =>
                    setState(() => _trackingMode = selection.first),
              ),
              const SizedBox(height: 8),
              PageTransitionSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 240),
                reverse: _trackingMode == _TrackingMode.manual,
                transitionBuilder: (child, animation, secondaryAnimation) =>
                    SharedAxisTransition(
                      animation: animation,
                      secondaryAnimation: secondaryAnimation,
                      transitionType: SharedAxisTransitionType.horizontal,
                      fillColor: Colors.transparent,
                      child: child,
                    ),
                child: Text(
                  _trackingMode == _TrackingMode.automatic
                      ? 'The app records a day when you arrive at this verified location.'
                      : 'You will record office days yourself. Location permissions are not needed.',
                  key: ValueKey(_trackingMode),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),

              if (_trackingMode == _TrackingMode.automatic) ...[
                const SizedBox(height: 24),
                TextFormField(
                  controller: _addressCtrl,
                  maxLines: 2,
                  onChanged: (_) => setState(() {
                    _lat = null;
                    _lng = null;
                    _locationError = null;
                  }),
                  decoration: const InputDecoration(
                    labelText: 'Office Address *',
                    hintText: 'Enter the complete office address',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final current = OutlinedButton.icon(
                      onPressed: _busy ? null : _useCurrentLocation,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Use current location'),
                    );
                    final search = FilledButton.tonalIcon(
                      onPressed: _busy ? null : _lookupAddress,
                      icon: const Icon(Icons.search),
                      label: const Text('Find address'),
                    );
                    if (constraints.maxWidth < 440) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [current, const SizedBox(height: 8), search],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: current),
                        const SizedBox(width: 8),
                        Expanded(child: search),
                      ],
                    );
                  },
                ),
                if (_busy) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(),
                ],
                if (_locationError != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline, color: cs.onErrorContainer),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _locationError!,
                            style: TextStyle(color: cs.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_lat != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.verified_outlined, color: cs.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Location confirmed',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(
                                '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Detection radius',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Chip(label: Text('${_radius.toInt()} m')),
                  ],
                ),
                Text(
                  'Use a larger radius if GPS reception is unreliable inside the building.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
              ] else ...[
                const SizedBox(height: 16),
                const Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: Icon(Icons.lock_outline),
                    title: Text('No location access'),
                    subtitle: Text(
                      'You can change this office to automatic tracking later.',
                    ),
                  ),
                ),
              ],

              // ── Region ────────────────────────────────────────────────────
              // Outside the tracking-mode branch on purpose: public holidays
              // are matched on country + state, whether or not the app watches
              // for arrivals. Editable because the desktop geocoder is a
              // best-effort HTTP service — when it returns nothing these are
              // the only way the office ever gets a region.
              const SizedBox(height: 24),
              Text(
                'Region for public holidays',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Filled in automatically when a location is resolved. Must '
                'match the published holiday list — e.g. AU and Victoria.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: TextFormField(
                      controller: _countryCtrl,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Country',
                        hintText: 'AU',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _stateCtrl,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'State',
                        hintText: 'Victoria',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              if (_regionMissing) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Without both, public holidays are never imported for '
                        'this office.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

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
      ),
    );
  }
}
