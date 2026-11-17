import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../app/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/facility.dart';
import '../services/facility_service.dart';
import '../services/sos_service.dart';
import '../widgets/app_widgets.dart';

/// Nearby care combines a live OpenStreetMap view with a list of facilities.
/// Location is requested only after an explicit tap and an explanation; manual
/// city, area or PIN search always remains available.
class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  final FacilityService _facilityService = FacilityService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final MapController _mapController = MapController();

  double? _latitude;
  double? _longitude;
  String _locationLabel = '';
  List<Facility> _facilities = const [];
  bool _loading = false;
  bool _locating = false;
  bool _searchingPlaces = false;
  bool _resolvingArea = false;
  bool _permissionBlocked = false;
  bool _permissionExplained = false;
  bool _mapReady = false;
  String? _error;
  String? _warning;
  String _source = 'OpenStreetMap';
  String _filter = 'all';
  String _view = 'map';
  double _radiusKm = 8;

  bool get _hasLocation => _latitude != null && _longitude != null;
  LatLng get _center => LatLng(_latitude ?? 0, _longitude ?? 0);

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _requestLocation() async {
    if (_permissionExplained) {
      await _useMyLocation();
      return;
    }
    final l10n = AppLocalizations.of(context);
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('nearby_allow_title')),
        content: Text(l10n.t('nearby_allow_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.t('not_now')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.t('allow_location')),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;
    _permissionExplained = true;
    await _useMyLocation();
  }

  Future<void> _useMyLocation() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _locating = true;
      _error = null;
      _permissionBlocked = false;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _locating = false;
            _error = l10n.t('location_services_off');
          });
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _locating = false;
            _error = l10n.t('location_permission_denied');
          });
        }
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locating = false;
            _permissionBlocked = true;
            _error = l10n.t('location_permission_forever');
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      ).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationLabel = l10n.t('current_location');
        _locating = false;
      });
      _centerMap();
      await _loadFacilities();
      unawaited(_resolveAreaName(position.latitude, position.longitude));
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _locating = false;
          _error = l10n.t('location_timeout');
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _locating = false;
          _error = l10n.t('location_unavailable');
        });
      }
    }
  }

  Future<void> _resolveAreaName(double latitude, double longitude) async {
    if (!mounted) return;
    setState(() => _resolvingArea = true);
    final place = await _facilityService.reverseGeocode(
      latitude: latitude,
      longitude: longitude,
    );
    if (!mounted) return;
    final label = place == null
        ? ''
        : [place.city, place.state]
            .where((value) => value.trim().isNotEmpty)
            .toSet()
            .join(', ');
    setState(() {
      _resolvingArea = false;
      if (label.isNotEmpty) _locationLabel = label;
    });
  }

  Future<void> _searchPlaces() async {
    final l10n = AppLocalizations.of(context);
    final query = _searchController.text.trim();
    if (query.length < 2) {
      showAppSnackBar(context, l10n.t('search_min_chars'), isError: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _searchingPlaces = true;
      _error = null;
    });
    final places = await _facilityService.searchPlaces(query);
    if (!mounted) return;
    setState(() => _searchingPlaces = false);
    if (places.isEmpty) {
      showAppSnackBar(context, l10n.t('place_search_empty'), isError: true);
      return;
    }
    final selected = await showModalBottomSheet<PlaceResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.74,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppSheetHeader(
                    title: l10n.t('select_area'),
                    subtitle: l10n.t('nearby_permission_rationale'),
                    icon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: places.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final place = places[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const AppIconBadge(
                            icon: Icons.place_outlined,
                            color: AppColors.teal,
                            background: AppColors.tealSoft,
                            size: 38,
                          ),
                          title: Text(
                            place.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () =>
                              Navigator.of(sheetContext).pop(place),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    setState(() {
      _latitude = selected.latitude;
      _longitude = selected.longitude;
      _locationLabel = selected.displayName;
      _view = 'map';
    });
    _centerMap();
    await _loadFacilities();
  }

  Future<void> _loadFacilities({double? radiusKm, String? filter}) async {
    final lat = _latitude;
    final lon = _longitude;
    if (lat == null || lon == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _warning = null;
      _radiusKm = radiusKm ?? _radiusKm;
      _filter = filter ?? _filter;
    });
    final result = await _facilityService.nearby(
      latitude: lat,
      longitude: lon,
      radiusKm: _radiusKm,
      type: _filter,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _facilities = result.facilities;
      _warning = result.warning;
      _source = result.source;
      _error = result.isError ? result.error?.message : null;
    });
  }

  void _centerMap() {
    if (!_hasLocation) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mapReady) return;
      _mapController.move(_center, 13.5);
    });
  }

  void _setView(String view) {
    setState(() => _view = view);
    if (view == 'map') _centerMap();
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      showAppSnackBar(
        context,
        AppLocalizations.of(context).t('no_phone'),
        isError: true,
      );
      return;
    }
    try {
      await SOSService.openDialer(phone);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          AppLocalizations.of(context).t('dialer_unavailable'),
          isError: true,
        );
      }
    }
  }

  Future<void> _openDirections(Facility facility) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${facility.latitude},${facility.longitude}',
    );
    final opened = await openExternalUrl(context, uri.toString());
    if (!opened && mounted) {
      final osm = Uri.parse(
        'https://www.openstreetmap.org/?mlat=${facility.latitude}&mlon=${facility.longitude}#map=16/${facility.latitude}/${facility.longitude}',
      );
      await openExternalUrl(context, osm.toString());
    }
  }

  Future<void> _openAreaMap() async {
    final lat = _latitude;
    final lon = _longitude;
    if (lat == null || lon == null) {
      await openExternalUrl(
        context,
        'https://www.openstreetmap.org/',
      );
      return;
    }
    await openExternalUrl(
      context,
      'https://www.openstreetmap.org/#map=14/$lat/$lon',
    );
  }

  Future<void> _openLocationSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          AppLocalizations.of(context).t('settings_unavailable'),
          isError: true,
        );
      }
    }
  }

  Future<void> _showFacility(Facility facility) async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.78,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppSheetHeader(
                    title: facility.displayName,
                    subtitle: facilityTypeLabel(l10n, facility.type),
                    icon: facilityTypeIcon(facility.type),
                  ),
                  const SizedBox(height: 14),
                  _FacilityDetails(
                    facility: facility,
                    onCall: () => _call(facility.phone),
                    onDirections: () => _openDirections(facility),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('nearby_title')),
        actions: [
          if (_hasLocation)
            IconButton(
              tooltip: l10n.t('refresh'),
              onPressed: _loading ? null : () => _loadFacilities(),
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _hasLocation ? () => _loadFacilities() : () async {},
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: ResponsiveBody(
                maxWidth: 940,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_hasLocation)
                      _LocationIntro(
                        locating: _locating,
                        error: _error,
                        permissionBlocked: _permissionBlocked,
                        onUseLocation: _requestLocation,
                        onSearch: () => _searchFocus.requestFocus(),
                        onOpenSettings: _openLocationSettings,
                      )
                    else
                      _LocationCard(
                        label: _resolvingArea
                            ? l10n.t('nearby_resolving_area')
                            : _locationLabel,
                        radiusKm: _radiusKm,
                        locating: _locating,
                        onUseLocation: _requestLocation,
                        onOpenMap: _openAreaMap,
                        searchField: _searchField(l10n),
                        onSearch: _searchingPlaces ? null : _searchPlaces,
                        searching: _searchingPlaces,
                        error: _error,
                        permissionBlocked: _permissionBlocked,
                        onOpenSettings: _openLocationSettings,
                      ),
                    if (!_hasLocation) ...[
                      const SizedBox(height: 12),
                      _SearchCard(
                        searchField: _searchField(l10n),
                        searching: _searchingPlaces,
                        onSearch: _searchPlaces,
                      ),
                      const SizedBox(height: 12),
                      AppInfoBanner(
                        icon: Icons.shield_outlined,
                        text: l10n.t('nearby_permission_explanation'),
                        color: AppColors.tealDark,
                        background: AppColors.tealSoft,
                      ),
                    ],
                    if (_hasLocation) ...[
                      const SizedBox(height: 14),
                      _FilterRow(
                        filter: _filter,
                        loading: _loading,
                        onChanged: (value) => _loadFacilities(filter: value),
                      ),
                      const SizedBox(height: 10),
                      _RadiusRow(
                        radiusKm: _radiusKm,
                        loading: _loading,
                        onChanged: (value) => _loadFacilities(radiusKm: value),
                      ),
                      if (_warning != null) ...[
                        const SizedBox(height: 10),
                        AppInfoBanner(
                          icon: Icons.info_outline_rounded,
                          text: _warning!,
                          color: AppColors.warning,
                          background: AppColors.warningSoft,
                        ),
                      ],
                      const SizedBox(height: 14),
                      _ResultsHeader(
                        view: _view,
                        count: _facilities.length,
                        radiusKm: _radiusKm,
                        loading: _loading,
                        onViewChanged: _setView,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (!_hasLocation)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ResponsiveBody(
                  maxWidth: 940,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: AppEmptyState(
                      icon: Icons.map_outlined,
                      title: l10n.t('nearby_choose_body'),
                      message: l10n.t('nearby_permission_explanation'),
                      actionLabel: l10n.t('use_my_location'),
                      onAction: _requestLocation,
                    ),
                  ),
                ),
              )
            else if (_view == 'map')
              SliverToBoxAdapter(
                child: ResponsiveBody(
                  maxWidth: 940,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MapPanel(
                        center: _center,
                        radiusKm: _radiusKm,
                        facilities: _facilities,
                        mapController: _mapController,
                        onMapReady: () => _mapReady = true,
                        onFacilityTap: _showFacility,
                        onRecenter: _centerMap,
                      ),
                      if (_loading) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(minHeight: 3),
                      ] else if (_error != null) ...[
                        const SizedBox(height: 12),
                        AppInfoBanner(
                          icon: Icons.error_outline_rounded,
                          text: _error!,
                          color: AppColors.danger,
                          background: AppColors.dangerSoft,
                          trailing: TextButton(
                            onPressed: () => _loadFacilities(),
                            child: Text(l10n.t('retry')),
                          ),
                        ),
                      ] else if (_facilities.isEmpty) ...[
                        const SizedBox(height: 12),
                        AppInfoBanner(
                          icon: Icons.search_off_rounded,
                          text: l10n.t('nearby_no_results_body'),
                          color: AppColors.slate,
                          background: AppColors.neutralSoft,
                          trailing: TextButton(
                            onPressed: () => _loadFacilities(radiusKm: 20),
                            child: Text(l10n.t('search_wider_area')),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _SourceNote(source: _source),
                    ],
                  ),
                ),
              )
            else if (_loading)
              const SliverToBoxAdapter(
                child: ResponsiveBody(
                  maxWidth: 940,
                  child: Column(
                    children: [
                      ArticleSkeleton(),
                      SizedBox(height: 10),
                      ArticleSkeleton(),
                      SizedBox(height: 10),
                      ArticleSkeleton(),
                    ],
                  ),
                ),
              )
            else if (_facilities.isEmpty && _error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ResponsiveBody(
                  maxWidth: 940,
                  child: AppErrorState(
                    title: l10n.t('nearby_unavailable'),
                    message: _error!,
                    onRetry: () => _loadFacilities(),
                  ),
                ),
              )
            else if (_facilities.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: ResponsiveBody(
                  maxWidth: 940,
                  child: AppEmptyState(
                    icon: Icons.local_hospital_outlined,
                    title: l10n.t('nearby_no_results_title'),
                    message: l10n.t('nearby_no_results_body'),
                    actionLabel: l10n.t('search_wider_area'),
                    onAction: () => _loadFacilities(radiusKm: 20),
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: ResponsiveBody(
                  maxWidth: 940,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    children: [
                      for (var i = 0; i < _facilities.length; i++) ...[
                        _FacilityCard(
                          facility: _facilities[i],
                          onTap: () => _showFacility(_facilities[i]),
                          onCall: () => _call(_facilities[i].phone),
                          onDirections: () => _openDirections(_facilities[i]),
                        ),
                        if (i != _facilities.length - 1)
                          const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 16),
                      _SourceNote(source: _source),
                      const SizedBox(height: 12),
                      AppInfoBanner(
                        icon: Icons.info_outline_rounded,
                        text: l10n.t('facility_disclaimer'),
                        color: AppColors.slate,
                        background: AppColors.neutralSoft,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _openAreaMap,
                        icon: const Icon(Icons.map_outlined),
                        label: Text(l10n.t('nearby_open_osm')),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _searchField(AppLocalizations l10n) {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocus,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: l10n.t('search_pin_hint'),
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                tooltip: l10n.t('nearby_clear_search'),
                onPressed: () {
                  setState(_searchController.clear);
                },
                icon: const Icon(Icons.close_rounded),
              ),
      ),
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _searchPlaces(),
    );
  }
}

class _LocationIntro extends StatelessWidget {
  final bool locating;
  final String? error;
  final bool permissionBlocked;
  final VoidCallback onUseLocation;
  final VoidCallback onSearch;
  final VoidCallback onOpenSettings;

  const _LocationIntro({
    required this.locating,
    required this.error,
    required this.permissionBlocked,
    required this.onUseLocation,
    required this.onSearch,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.teal,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppShadows.brand,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.near_me_outlined,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.t('nearby_allow_title'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t('nearby_allow_body'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: 13,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              FilledButton.icon(
                onPressed: locating ? null : onUseLocation,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.tealDark,
                ),
                icon: locating
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_rounded, size: 18),
                label: Text(l10n.t('allow_location')),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onSearch,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: Text(l10n.t('search_city_or_area')),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (permissionBlocked)
                    TextButton(
                      onPressed: onOpenSettings,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text(l10n.t('open_settings')),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final String label;
  final double radiusKm;
  final bool locating;
  final VoidCallback onUseLocation;
  final VoidCallback onOpenMap;
  final Widget searchField;
  final VoidCallback? onSearch;
  final bool searching;
  final String? error;
  final bool permissionBlocked;
  final VoidCallback onOpenSettings;

  const _LocationCard({
    required this.label,
    required this.radiusKm,
    required this.locating,
    required this.onUseLocation,
    required this.onOpenMap,
    required this.searchField,
    required this.onSearch,
    required this.searching,
    required this.error,
    required this.permissionBlocked,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppIconBadge(
                  icon: Icons.place_outlined,
                  color: AppColors.teal,
                  background: AppColors.tealSoft,
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.t('nearby_area_label'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l10n
                            .t('within_radius')
                            .replaceAll('{radius}', _formatRadius(radiusKm)),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.t('nearby_open_osm'),
                  onPressed: onOpenMap,
                  icon: const Icon(Icons.open_in_new_rounded, size: 19),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: locating ? null : onUseLocation,
                    icon: locating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded, size: 18),
                    label: Text(
                      locating
                          ? l10n.t('nearby_resolving_area')
                          : l10n.t('nearby_refresh_location'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: l10n.t('search'),
                  onPressed: onSearch,
                  icon: searching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.arrow_forward_rounded),
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              AppInfoBanner(
                icon: Icons.error_outline_rounded,
                text: error!,
                color: AppColors.danger,
                background: AppColors.dangerSoft,
                trailing: permissionBlocked
                    ? TextButton(
                        onPressed: onOpenSettings,
                        child: Text(l10n.t('open_settings')),
                      )
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  final Widget searchField;
  final bool searching;
  final VoidCallback onSearch;

  const _SearchCard({
    required this.searchField,
    required this.searching,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.t('choose_area'),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: l10n.t('search'),
                  onPressed: searching ? null : onSearch,
                  icon: searching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.arrow_forward_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.t('location_permission_rationale'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final String filter;
  final bool loading;
  final ValueChanged<String> onChanged;

  const _FilterRow({
    required this.filter,
    required this.loading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in const [
            ('all', 'filter_all', Icons.apps_rounded),
            ('hospital', 'filter_hospitals', Icons.local_hospital_outlined),
            ('clinic', 'filter_clinics', Icons.medical_services_outlined),
            ('pharmacy', 'filter_pharmacies', Icons.local_pharmacy_outlined),
          ]) ...[
            ChoiceChip(
              avatar: Icon(
                item.$3,
                size: 16,
                color: filter == item.$1 ? AppColors.tealDark : AppColors.slate,
              ),
              label: Text(l10n.t(item.$2)),
              selected: filter == item.$1,
              onSelected: loading ? null : (_) => onChanged(item.$1),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _RadiusRow extends StatelessWidget {
  final double radiusKm;
  final bool loading;
  final ValueChanged<double> onChanged;

  const _RadiusRow({
    required this.radiusKm,
    required this.loading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Text(
          l10n.t('search_radius'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final radius in const [2.0, 5.0, 8.0, 15.0, 25.0]) ...[
                  ChoiceChip(
                    label: Text(
                      l10n
                          .t('radius_km')
                          .replaceAll('{km}', _formatRadius(radius)),
                    ),
                    selected: radiusKm == radius,
                    onSelected:
                        loading ? null : (_) => onChanged(radius),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  final String view;
  final int count;
  final double radiusKm;
  final bool loading;
  final ValueChanged<String> onViewChanged;

  const _ResultsHeader({
    required this.view,
    required this.count,
    required this.radiusKm,
    required this.loading,
    required this.onViewChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t('nearby_places_title'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                loading
                    ? l10n.t('nearby_refresh_hint')
                    : l10n.t('nearby_results_count').replaceAll(
                          '{count}',
                          '$count',
                        ).replaceAll('{radius}', _formatRadius(radiusKm)),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        _ViewToggle(view: view, onChanged: onViewChanged),
      ],
    );
  }
}

class _ViewToggle extends StatelessWidget {
  final String view;
  final ValueChanged<String> onChanged;

  const _ViewToggle({required this.view, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleItem(
            label: l10n.t('nearby_map'),
            icon: Icons.map_outlined,
            selected: view == 'map',
            onTap: () => onChanged('map'),
          ),
          _ToggleItem(
            label: l10n.t('nearby_list'),
            icon: Icons.view_list_outlined,
            selected: view == 'list',
            onTap: () => onChanged('list'),
          ),
        ],
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected ? AppShadows.card : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? AppColors.tealDark : AppColors.slate,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? AppColors.tealDark : AppColors.slate,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapPanel extends StatelessWidget {
  final LatLng center;
  final double radiusKm;
  final List<Facility> facilities;
  final MapController mapController;
  final VoidCallback onMapReady;
  final ValueChanged<Facility> onFacilityTap;
  final VoidCallback onRecenter;

  const _MapPanel({
    required this.center,
    required this.radiusKm,
    required this.facilities,
    required this.mapController,
    required this.onMapReady,
    required this.onFacilityTap,
    required this.onRecenter,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final height =
        (MediaQuery.sizeOf(context).height * 0.46).clamp(300.0, 440.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 13,
                minZoom: 4,
                maxZoom: 18,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onMapReady: onMapReady,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.healthmate.app',
                  maxZoom: 19,
                ),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: center,
                      radius: radiusKm * 1000,
                      useRadiusInMeter: true,
                      color: AppColors.teal.withValues(alpha: 0.08),
                      borderColor: AppColors.teal.withValues(alpha: 0.38),
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: center,
                      width: 36,
                      height: 36,
                      child: const _CurrentLocationDot(),
                    ),
                    for (final facility in facilities)
                      Marker(
                        point: LatLng(
                          facility.latitude,
                          facility.longitude,
                        ),
                        width: 42,
                        height: 42,
                        alignment: Alignment.topCenter,
                        child: _FacilityPin(
                          facility: facility,
                          onTap: () => onFacilityTap(facility),
                        ),
                      ),
                  ],
                ),
                RichAttributionWidget(
                  showFlutterMapAttribution: false,
                  popupBackgroundColor: AppColors.surface,
                  attributions: [
                    TextSourceAttribution(
                      l10n.t('map_attribution').replaceAll('© ', ''),
                      onTap: () => openExternalUrl(
                        context,
                        'https://www.openstreetmap.org/copyright',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: AppShadows.card,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.touch_app_outlined,
                      size: 14,
                      color: AppColors.slate,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      l10n.t('nearby_map_hint'),
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Material(
                color: Colors.white,
                elevation: 2,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: l10n.t('current_location'),
                  onPressed: onRecenter,
                  icon: const Icon(
                    Icons.my_location_rounded,
                    size: 19,
                    color: AppColors.tealDark,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentLocationDot extends StatelessWidget {
  const _CurrentLocationDot();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: AppColors.info,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x332563A8),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _FacilityPin extends StatelessWidget {
  final Facility facility;
  final VoidCallback onTap;

  const _FacilityPin({required this.facility, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = facilityColor(facility.type);
    return Semantics(
      button: true,
      label: facility.displayName,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x330D2733),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            facilityTypeIcon(facility.type),
            color: Colors.white,
            size: 19,
          ),
        ),
      ),
    );
  }
}

class _FacilityCard extends StatelessWidget {
  final Facility facility;
  final VoidCallback onTap;
  final VoidCallback onCall;
  final VoidCallback onDirections;

  const _FacilityCard({
    required this.facility,
    required this.onTap,
    required this.onCall,
    required this.onDirections,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = facilityColor(facility.type);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIconBadge(
                    icon: facilityTypeIcon(facility.type),
                    color: color,
                    background: color.withValues(alpha: 0.1),
                    size: 44,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          facility.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          facilityTypeLabel(l10n, facility.type),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (facility.distanceKm != null)
                    AppStatusChip(
                      label:
                          '${facility.distanceKm!.toStringAsFixed(facility.distanceKm! < 10 ? 1 : 0)} km',
                      color: AppColors.slate,
                      background: AppColors.neutralSoft,
                      icon: Icons.near_me_outlined,
                    ),
                ],
              ),
              if (facility.address.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: AppColors.slate,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        facility.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ],
              if (facility.openingHours != null &&
                  facility.openingHours!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_outlined,
                      size: 16,
                      color: AppColors.slate,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        facility.openingHours!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: facility.phone == null ? null : onCall,
                      icon: const Icon(Icons.call_outlined, size: 18),
                      label: Text(
                        facility.phone == null
                            ? l10n.t('no_phone')
                            : l10n.t('call'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: onDirections,
                      icon: const Icon(Icons.directions_outlined, size: 18),
                      label: Text(l10n.t('directions')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FacilityDetails extends StatelessWidget {
  final Facility facility;
  final VoidCallback onCall;
  final VoidCallback onDirections;

  const _FacilityDetails({
    required this.facility,
    required this.onCall,
    required this.onDirections,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = facilityColor(facility.type);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AppIconBadge(
              icon: facilityTypeIcon(facility.type),
              color: color,
              background: color.withValues(alpha: 0.1),
              size: 46,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                facility.displayName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            if (facility.distanceKm != null)
              AppStatusChip(
                label:
                    '${facility.distanceKm!.toStringAsFixed(facility.distanceKm! < 10 ? 1 : 0)} km',
                color: AppColors.slate,
                background: AppColors.neutralSoft,
                icon: Icons.near_me_outlined,
              ),
          ],
        ),
        const SizedBox(height: 14),
        _DetailLine(
          icon: Icons.location_on_outlined,
          text: facility.address.trim().isEmpty
              ? l10n.t('facility_no_address')
              : facility.address,
        ),
        if (facility.phone != null && facility.phone!.isNotEmpty)
          _DetailLine(
            icon: Icons.call_outlined,
            text: facility.phone!,
          ),
        if (facility.openingHours != null &&
            facility.openingHours!.isNotEmpty)
          _DetailLine(
            icon: Icons.schedule_outlined,
            text: facility.openingHours!,
          ),
        if (facility.website != null && facility.website!.isNotEmpty)
          _DetailLine(
            icon: Icons.language_outlined,
            text: l10n.t('facility_website'),
            trailing: TextButton(
              onPressed: () =>
                  openExternalUrl(context, facility.website),
              child: Text(l10n.t('view_details')),
            ),
          ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: facility.phone == null ? null : onCall,
                icon: const Icon(Icons.call_outlined, size: 18),
                label: Text(
                  facility.phone == null
                      ? l10n.t('no_phone')
                      : l10n.t('call'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: onDirections,
                icon: const Icon(Icons.directions_outlined, size: 18),
                label: Text(l10n.t('directions')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppInfoBanner(
          icon: Icons.info_outline_rounded,
          text: l10n.t('facility_disclaimer'),
          color: AppColors.slate,
          background: AppColors.neutralSoft,
        ),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? trailing;

  const _DetailLine({required this.icon, required this.text, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.slate),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 13, height: 1.45),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _SourceNote extends StatelessWidget {
  final String source;
  const _SourceNote({required this.source});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        const Icon(
          Icons.public_rounded,
          size: 13,
          color: AppColors.slate,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            source.toLowerCase().contains('openstreetmap')
                ? l10n.t('facility_source')
                : source,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontSize: 10.5),
          ),
        ),
      ],
    );
  }
}

String facilityTypeLabel(AppLocalizations l10n, String type) {
  switch (type) {
    case 'clinic':
      return l10n.t('clinic');
    case 'doctors':
      return l10n.t('doctors_office');
    case 'pharmacy':
      return l10n.t('pharmacy');
    case 'hospital':
      return l10n.t('hospital');
    default:
      return l10n.t('facility_type_unknown');
  }
}

IconData facilityTypeIcon(String type) {
  switch (type) {
    case 'pharmacy':
      return Icons.local_pharmacy_outlined;
    case 'clinic':
    case 'doctors':
      return Icons.medical_services_outlined;
    default:
      return Icons.local_hospital_outlined;
  }
}

Color facilityColor(String type) {
  switch (type) {
    case 'pharmacy':
      return AppColors.warning;
    case 'clinic':
    case 'doctors':
      return AppColors.info;
    default:
      return AppColors.teal;
  }
}

String _formatRadius(double radius) {
  return radius == radius.roundToDouble()
      ? radius.toStringAsFixed(0)
      : radius.toStringAsFixed(1);
}
