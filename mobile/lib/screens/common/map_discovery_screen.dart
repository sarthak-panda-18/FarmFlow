import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';

class MapDiscoveryScreen extends StatefulWidget {
  final String userRole; // 'FARMER' or 'BUYER'

  const MapDiscoveryScreen({
    super.key,
    required this.userRole,
  });

  @override
  State<MapDiscoveryScreen> createState() => _MapDiscoveryScreenState();
}

class _MapDiscoveryScreenState extends State<MapDiscoveryScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();

  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;

  // Current user GPS info
  double? _myLat;
  double? _myLng;
  String _myAddress = '';
  bool _isUpdatingGps = false;

  // Filters
  double _selectedRadius = 50.0;
  final List<double> _radiusOptions = [10.0, 25.0, 50.0, 100.0, 250.0];

  List<dynamic> _nearbyPeers = [];
  List<dynamic> _nearbyMarkets = [];

  bool get _isFarmer => widget.userRole.toUpperCase() == 'FARMER';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLocationAndData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLocationAndData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Fetch saved location from backend
      final locRes = await _apiService.getMyLocation();
      if (locRes.data != null && locRes.data['success'] == true) {
        final data = locRes.data['data'];
        if (data['hasCoordinates'] == true) {
          _myLat = (data['latitude'] as num?)?.toDouble();
          _myLng = (data['longitude'] as num?)?.toDouble();
          _myAddress = data['address'] ?? data['district'] ?? '';
        }
      }

      // If no location stored yet, attempt device GPS
      if (_myLat == null || _myLng == null) {
        final gpsResult = await _locationService.getCurrentPosition();
        if (gpsResult.isSuccess && gpsResult.position != null) {
          _myLat = gpsResult.position!.latitude;
          _myLng = gpsResult.position!.longitude;
          await _apiService.updateLocation(
            latitude: _myLat!,
            longitude: _myLng!,
          );
        }
      }

      await _fetchNearbyEntities();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshGpsLocation() async {
    setState(() => _isUpdatingGps = true);
    try {
      final gpsResult = await _locationService.getCurrentPosition();
      if (gpsResult.isSuccess && gpsResult.position != null) {
        _myLat = gpsResult.position!.latitude;
        _myLng = gpsResult.position!.longitude;

        await _apiService.updateLocation(
          latitude: _myLat!,
          longitude: _myLng!,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📍 GPS updated: ${_myLat!.toStringAsFixed(4)}, ${_myLng!.toStringAsFixed(4)}'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        await _fetchNearbyEntities();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(gpsResult.errorMessage ?? 'Unable to acquire GPS location'),
              backgroundColor: AppColors.error,
              action: SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () => _locationService.openAppSettings(),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating location: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingGps = false);
    }
  }

  Future<void> _fetchNearbyEntities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      late final dynamic peerRes;
      if (_isFarmer) {
        // Farmer looks for nearby Buyers
        peerRes = await _apiService.getNearbyBuyers(
          latitude: _myLat,
          longitude: _myLng,
          maxDistanceKm: _selectedRadius,
        );
      } else {
        // Buyer looks for nearby Farmers
        peerRes = await _apiService.getNearbyFarmers(
          latitude: _myLat,
          longitude: _myLng,
          maxDistanceKm: _selectedRadius,
        );
      }

      final marketRes = await _apiService.getNearbyMarkets(
        latitude: _myLat,
        longitude: _myLng,
        maxDistanceKm: _selectedRadius,
      );

      if (mounted) {
        setState(() {
          if (peerRes.data != null && peerRes.data['success'] == true) {
            _nearbyPeers = peerRes.data['data'] ?? [];
          }
          if (marketRes.data != null && marketRes.data['success'] == true) {
            _nearbyMarkets = marketRes.data['data'] ?? [];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _openGoogleMapsForCoordinate(double lat, double lng, String label) {
    _locationService.openGoogleMaps(
      latitude: lat,
      longitude: lng,
      label: label,
    );
  }

  @override
  Widget build(BuildContext context) {
    final peerTabTitle = _isFarmer ? 'Nearby Buyers' : 'Nearby Farmers';
    final primaryColor = _isFarmer ? AppColors.primary : AppColors.secondary;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Map & Nearby Discovery'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(icon: const Icon(Icons.people_outline), text: peerTabTitle),
            const Tab(icon: Icon(Icons.storefront_outlined), text: 'APMC Markets'),
          ],
        ),
      ),
      body: Column(
        children: [
          // GPS Location Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.my_location, color: primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Current Location',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _myLat != null && _myLng != null
                            ? '${_myLat!.toStringAsFixed(4)}, ${_myLng!.toStringAsFixed(4)} ${_myAddress.isNotEmpty ? "• $_myAddress" : ""}'
                            : 'GPS Location Not Set',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _isUpdatingGps ? null : _refreshGpsLocation,
                  icon: _isUpdatingGps
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh, size: 16),
                  label: const Text('Update GPS', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),

          // Distance Radius Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[50],
            child: Row(
              children: [
                const Text('Radius: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _radiusOptions.map((r) {
                        final isSelected = _selectedRadius == r;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text('${r.toInt()} km'),
                            selected: isSelected,
                            selectedColor: primaryColor.withValues(alpha: 0.2),
                            labelStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? primaryColor : AppColors.textSecondary,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedRadius = r);
                                _fetchNearbyEntities();
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPeersList(primaryColor),
                _buildMarketsList(primaryColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeersList(Color primaryColor) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchNearbyEntities,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_nearbyPeers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off_outlined, size: 56, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                _isFarmer ? 'No nearby Buyers found within ${_selectedRadius.toInt()} km' : 'No nearby Farmers found within ${_selectedRadius.toInt()} km',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Try increasing the search radius above to discover participants in neighboring districts.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingSmall),
      itemCount: _nearbyPeers.length,
      itemBuilder: (context, index) {
        final item = _nearbyPeers[index];
        final name = item['name'] ?? (_isFarmer ? 'Buyer' : 'Farmer');
        final dist = (item['distanceKm'] as num?)?.toDouble() ?? 0.0;
        final lat = (item['latitude'] as num?)?.toDouble();
        final lng = (item['longitude'] as num?)?.toDouble();
        final address = item['address'] ?? '${item['district'] ?? ""}, ${item['state'] ?? ""}';

        final cropsOrReqs = _isFarmer
            ? (item['requirements'] as List? ?? [])
            : (item['crops'] as List? ?? []);

        return Card(
          elevation: AppConstants.cardElevation,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Name & Distance Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: primaryColor.withValues(alpha: 0.15),
                            child: Icon(_isFarmer ? Icons.store : Icons.agriculture, color: primaryColor, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  address,
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.near_me, size: 12, color: Color(0xFF2563EB)),
                          const SizedBox(width: 4),
                          Text(
                            '${dist.toStringAsFixed(1)} km',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (cropsOrReqs.isNotEmpty) ...[
                  const Divider(height: 16),
                  Text(
                    _isFarmer ? 'Active Requirements (${cropsOrReqs.length}):' : 'Available Crops (${cropsOrReqs.length}):',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: cropsOrReqs.take(4).map((c) {
                      final comm = c['commodity'] ?? c['cropName'] ?? '';
                      final qty = c['quantity'] ?? '';
                      final unit = c['quantityUnit'] ?? '';
                      return Chip(
                        label: Text('$comm ($qty $unit)', style: const TextStyle(fontSize: 11)),
                        backgroundColor: const Color(0xFFF1F5F9),
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 12),
                // Action: Open in Google Maps
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: lat != null && lng != null
                        ? () => _openGoogleMapsForCoordinate(lat, lng, name)
                        : null,
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Open in Google Maps / Get Directions'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMarketsList(Color primaryColor) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_nearbyMarkets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.storefront_outlined, size: 56, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'No APMC markets within ${_selectedRadius.toInt()} km',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Try selecting 25 km, 50 km, or 100 km above to discover nearby APMC mandis in neighboring districts (e.g. Guntur, Krishna).',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingSmall),
      itemCount: _nearbyMarkets.length,
      itemBuilder: (context, index) {
        final m = _nearbyMarkets[index];
        final marketName = m['market'] ?? 'APMC Market';
        final district = m['district'] ?? '';
        final state = m['state'] ?? '';
        final dist = (m['distanceKm'] as num?)?.toDouble();
        final lat = (m['latitude'] as num?)?.toDouble();
        final lng = (m['longitude'] as num?)?.toDouble();
        final sampleComm = m['sampleCommodity'] ?? '';
        final samplePrice = (m['samplePrice'] as num?)?.toDouble() ?? 0.0;
        final date = m['latestDate'] ?? '';

        return Card(
          elevation: AppConstants.cardElevation,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: Color(0xFFDCFCE7),
                            child: Icon(Icons.storefront, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$marketName APMC Mandi',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '$district, $state',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (dist != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.near_me, size: 12, color: Color(0xFF2563EB)),
                            const SizedBox(width: 4),
                            Text(
                              '${dist.toStringAsFixed(1)} km',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (sampleComm.isNotEmpty) ...[
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent Rate: $sampleComm', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text('₹${samplePrice.toStringAsFixed(0)} / Quintal', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ],
                  ),
                  if (date.isNotEmpty)
                    Text('Date: $date', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final queryLabel = '$marketName APMC Mandi, $district, $state';
                      if (lat != null && lng != null) {
                        _openGoogleMapsForCoordinate(lat, lng, queryLabel);
                      } else {
                        _locationService.openGoogleMaps(
                          latitude: _myLat ?? 16.5062,
                          longitude: _myLng ?? 80.6480,
                          label: queryLabel,
                        );
                      }
                    },
                    icon: const Icon(Icons.directions, size: 18),
                    label: const Text('View Mandi on Google Maps'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
