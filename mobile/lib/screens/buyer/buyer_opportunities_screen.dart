import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/buyer_opportunity_model.dart';
import '../../models/opportunity_model.dart';
import '../../services/api_service.dart';

class BuyerOpportunitiesScreen extends StatefulWidget {
  const BuyerOpportunitiesScreen({super.key});

  @override
  State<BuyerOpportunitiesScreen> createState() => _BuyerOpportunitiesScreenState();
}

class _BuyerOpportunitiesScreenState extends State<BuyerOpportunitiesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();

  bool _isLoadingMy = true;
  bool _isLoadingDiscover = true;
  String? _errorMy;
  String? _errorDiscover;

  List<OpportunityModel> _myOpportunities = [];
  List<DiscoverFarmerCropModel> _discoverCrops = [];

  String _selectedFilter = 'ALL';
  final List<String> _filters = ['ALL', 'PENDING', 'ACCEPTED', 'COMPLETED', 'REJECTED', 'CANCELLED'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        if (_tabController.index == 0) {
          _fetchMyOpportunities();
        } else {
          _fetchDiscoverCrops();
        }
      }
    });
    _fetchMyOpportunities();
    _fetchDiscoverCrops();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchMyOpportunities() async {
    setState(() {
      _isLoadingMy = true;
      _errorMy = null;
    });

    try {
      final res = await _apiService.getBuyerOpportunities(
        page: 1,
        limit: 100,
        status: _selectedFilter == 'ALL' ? null : _selectedFilter,
      );
      if (mounted && res.data != null && res.data['success'] == true) {
        final List list = res.data['data'] ?? [];
        setState(() {
          _myOpportunities = list.map((item) => OpportunityModel.fromJson(item)).toList();
          _isLoadingMy = false;
        });
      } else {
        setState(() {
          _errorMy = res.data?['message'] ?? 'Unable to load opportunities.';
          _isLoadingMy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMy = 'Unable to load opportunities.';
          _isLoadingMy = false;
        });
      }
    }
  }

  Future<void> _fetchDiscoverCrops() async {
    setState(() {
      _isLoadingDiscover = true;
      _errorDiscover = null;
    });

    try {
      final res = await _apiService.getDiscoverableFarmerCrops(page: 1, limit: 50);
      if (mounted && res.data != null && res.data['success'] == true) {
        final List list = res.data['data'] ?? [];
        setState(() {
          _discoverCrops = list.map((item) => DiscoverFarmerCropModel.fromJson(item)).toList();
          _isLoadingDiscover = false;
        });
      } else {
        setState(() {
          _errorDiscover = res.data?['message'] ?? 'Unable to load farmer crops.';
          _isLoadingDiscover = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorDiscover = 'Unable to load farmer crops.';
          _isLoadingDiscover = false;
        });
      }
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
      case 'INTERESTED':
        return const Color(0xFFFEF3C7);
      case 'ACCEPTED':
        return const Color(0xFFDCFCE7);
      case 'COMPLETED':
      case 'CLOSED':
        return const Color(0xFFDBEAFE);
      case 'REJECTED':
      case 'CANCELLED':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
      case 'INTERESTED':
        return const Color(0xFF92400E);
      case 'ACCEPTED':
        return const Color(0xFF166534);
      case 'COMPLETED':
      case 'CLOSED':
        return const Color(0xFF1E40AF);
      case 'REJECTED':
      case 'CANCELLED':
        return const Color(0xFF991B1B);
      default:
        return const Color(0xFF374151);
    }
  }

  Widget _buildRatingBadge(double? rating, int count, bool isNew) {
    if (isNew || rating == null || count == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF59E0B)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, size: 13, color: Color(0xFFD97706)),
            SizedBox(width: 4),
            Text(
              'New Farmer',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 13, color: Color(0xFFD97706)),
          const SizedBox(width: 4),
          Text(
            '${rating.toStringAsFixed(1)} ($count)',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
          ),
        ],
      ),
    );
  }

  void _showExpressInterestDialog(DiscoverFarmerCropModel crop) {
    final priceController = TextEditingController(text: crop.expectedPrice.toStringAsFixed(0));
    final notesController = TextEditingController();
    bool isSubmitting = false;
    String? dialogError;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Express Interest: ${crop.commodity}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Farmer: ${crop.farmerName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Available: ${crop.quantity} ${crop.quantityUnit}'),
                    Text('Asking Price: ₹${crop.expectedPrice.toStringAsFixed(0)} / ${crop.quantityUnit}'),
                    const SizedBox(height: 12),
                    if (dialogError != null) ...[
                      Text(dialogError!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                      const SizedBox(height: 8),
                    ],
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Your Offered Price (₹) *',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes to Farmer (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final offered = double.tryParse(priceController.text.trim());
                          if (offered == null || offered <= 0) {
                            setModalState(() => dialogError = 'Please enter a valid offered price.');
                            return;
                          }

                          setModalState(() {
                            isSubmitting = true;
                            dialogError = null;
                          });

                          try {
                            final res = await _apiService.expressInterest(
                              cropId: crop.id,
                              offeredPrice: offered,
                              notes: notesController.text.trim(),
                            );

                            if (res.data != null && res.data['success'] == true) {
                              if (context.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Interest expressed successfully! Farmer has been notified.'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                                _fetchMyOpportunities();
                                _fetchDiscoverCrops();
                              }
                            } else {
                              setModalState(() {
                                isSubmitting = false;
                                dialogError = res.data?['message'] ?? 'Unable to express interest.';
                              });
                            }
                          } catch (e) {
                            setModalState(() {
                              isSubmitting = false;
                              dialogError = e.toString().replaceAll('Exception: ', '');
                            });
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Express Interest'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Farmer Opportunities'),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'My Opportunities'),
            Tab(text: 'Discover Farmer Crops'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              if (_tabController.index == 0) {
                _fetchMyOpportunities();
              } else {
                _fetchDiscoverCrops();
              }
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyOpportunitiesTab(),
          _buildDiscoverCropsTab(),
        ],
      ),
    );
  }

  Widget _buildMyOpportunitiesTab() {
    return Column(
      children: [
        // Filter Chips
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      filter == 'ALL' ? 'All Opportunities' : filter,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.secondary : AppColors.textSecondary,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.secondary.withValues(alpha: 0.15),
                    backgroundColor: const Color(0xFFF1F5F9),
                    onSelected: (selected) {
                      if (selected && _selectedFilter != filter) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                        _fetchMyOpportunities();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchMyOpportunities,
            child: _buildOpportunitiesList(),
          ),
        ),
      ],
    );
  }

  Widget _buildOpportunitiesList() {
    if (_isLoadingMy) {
      return const Center(child: CircularProgressIndicator(color: AppColors.secondary));
    }

    if (_errorMy != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(_errorMy!, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchMyOpportunities,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    if (_myOpportunities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.handshake_outlined, size: 64, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text(
                _selectedFilter == 'ALL'
                    ? 'No opportunities yet.'
                    : 'No $_selectedFilter opportunities.',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Explore the "Discover Farmer Crops" tab or express interest from Matched Crops.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  _tabController.animateTo(1);
                },
                icon: const Icon(Icons.search),
                label: const Text('Discover Farmer Crops'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      itemCount: _myOpportunities.length,
      itemBuilder: (context, index) {
        final op = _myOpportunities[index];
        final isInitiator = op.initiatedBy == 'BUYER';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: AppConstants.cardElevation,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
          child: InkWell(
            onTap: () async {
              final refreshed = await context.push(
                AppConstants.routeOpportunityDetail,
                extra: op.id,
              );
              if (refreshed == true) _fetchMyOpportunities();
            },
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Commodity Title & Status Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          op.commodity,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusBgColor(op.normalizedStatus),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          op.normalizedStatus,
                          style: TextStyle(
                            color: _getStatusTextColor(op.normalizedStatus),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Row 2: Initiator Tag & Farmer Name
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isInitiator ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isInitiator ? const Color(0xFFBFDBFE) : const Color(0xFFBBF7D0),
                          ),
                        ),
                        child: Text(
                          isInitiator ? 'Initiated by You' : 'Initiated by Farmer',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isInitiator ? const Color(0xFF1D4ED8) : const Color(0xFF15803D),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Farmer: ${op.farmerName}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const Divider(height: 16),

                  // Row 3: Quantities & Offered Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Quantity: ${op.quantity} ${op.quantityUnit}', style: const TextStyle(fontSize: 13)),
                      Text(
                        'Offered: ₹${op.offeredPrice.toStringAsFixed(0)} / ${op.quantityUnit}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.secondary),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Row 4: Distance & Details Action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (op.distanceKm != null)
                        Row(
                          children: [
                            const Icon(Icons.near_me, size: 14, color: AppColors.secondary),
                            const SizedBox(width: 4),
                            Text(
                              '${op.distanceKm!.toStringAsFixed(1)} km away',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        )
                      else
                        const SizedBox.shrink(),
                      const Row(
                        children: [
                          Text(
                            'View Details',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary),
                          ),
                          SizedBox(width: 2),
                          Icon(Icons.chevron_right, size: 16, color: AppColors.secondary),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDiscoverCropsTab() {
    if (_isLoadingDiscover) {
      return const Center(child: CircularProgressIndicator(color: AppColors.secondary));
    }

    if (_errorDiscover != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(_errorDiscover!, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchDiscoverCrops,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    if (_discoverCrops.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.eco_outlined, size: 64, color: AppColors.textMuted),
              SizedBox(height: 16),
              Text(
                'No farmer crops available currently.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchDiscoverCrops,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        itemCount: _discoverCrops.length,
        itemBuilder: (context, index) {
          final crop = _discoverCrops[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: AppConstants.cardElevation,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          crop.commodity,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        '₹${crop.expectedPrice.toStringAsFixed(0)} / ${crop.quantityUnit}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Farmer: ${crop.farmerName}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const SizedBox(width: 8),
                      _buildRatingBadge(crop.farmerRating, crop.farmerRatingCount, crop.farmerIsNew),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Available: ${crop.quantity} ${crop.quantityUnit} • Variety: ${crop.variety}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        crop.market.isNotEmpty ? '${crop.market}, ${crop.district}' : crop.district,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: crop.userInterestStatus != null
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusBgColor(crop.userInterestStatus!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Interest: ${crop.userInterestStatus!}',
                              style: TextStyle(
                                color: _getStatusTextColor(crop.userInterestStatus!),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          )
                        : ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _showExpressInterestDialog(crop),
                            icon: const Icon(Icons.thumb_up_alt_outlined, size: 16),
                            label: const Text('Express Interest', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
