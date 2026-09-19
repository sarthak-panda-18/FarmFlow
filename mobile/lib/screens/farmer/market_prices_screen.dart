import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/market_price.dart';
import '../../services/api_service.dart';

class MarketPricesScreen extends StatefulWidget {
  const MarketPricesScreen({super.key});

  @override
  State<MarketPricesScreen> createState() => _MarketPricesScreenState();
}

class _MarketPricesScreenState extends State<MarketPricesScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  String? _errorMessage;

  List<MarketPriceModel> _prices = [];
  List<String> _commodities = [];
  List<String> _states = [];

  String _selectedCategory = 'all';
  String? _selectedCommodity;
  String? _selectedState;
  final TextEditingController _searchController = TextEditingController();

  int _currentPage = 1;
  int _totalPages = 1;
  int _totalRecords = 0;
  static const int _pageSize = 15;

  final List<Map<String, String>> _categories = [
    {'id': 'all', 'name': 'All'},
    {'id': 'vegetables', 'name': 'Vegetables'},
    {'id': 'pulses', 'name': 'Pulses'},
    {'id': 'cereals', 'name': 'Cereals & Grains'},
    {'id': 'fruits', 'name': 'Fruits'},
    {'id': 'oilseeds', 'name': 'Oilseeds'},
    {'id': 'commercial', 'name': 'Commercial'},
  ];

  @override
  void initState() {
    super.initState();
    _loadFiltersAndData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFiltersAndData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _apiService.getCommodities(),
        _apiService.getStates(),
      ]);

      if (results[0].data != null && results[0].data['success'] == true) {
        _commodities = List<String>.from(results[0].data['data']);
      }

      if (results[1].data != null && results[1].data['success'] == true) {
        _states = List<String>.from(results[1].data['data']);
      }
    } catch (_) {
      // Ignore filter load failures gracefully
    }

    await _fetchMarketPrices();
  }

  Future<void> _fetchMarketPrices({int page = 1}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final query = _searchController.text.trim();
      late final dynamic response;

      if (query.isNotEmpty) {
        response = await _apiService.searchMarkets(
          q: query,
          commodity: _selectedCommodity,
          state: _selectedState,
          page: page,
          limit: _pageSize,
        );
      } else {
        response = await _apiService.getMarketPrices(
          commodity: _selectedCommodity,
          category: _selectedCategory != 'all' ? _selectedCategory : null,
          state: _selectedState,
          page: page,
          limit: _pageSize,
        );
      }

      final data = response.data;
      if (data != null && data['success'] == true) {
        final List list = data['data'] ?? [];
        setState(() {
          _prices = list.map((item) => MarketPriceModel.fromJson(item)).toList();
          _currentPage = data['page'] ?? 1;
          _totalPages = data['pages'] ?? 1;
          _totalRecords = data['total'] ?? 0;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = data['message'] ?? 'Failed to load market prices';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    _fetchMarketPrices(page: 1);
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = 'all';
      _selectedCommodity = null;
      _selectedState = null;
      _searchController.clear();
    });
    _fetchMarketPrices(page: 1);
  }

  void _showTrendsModal(MarketPriceModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(AppConstants.paddingLarge),
              child: FutureBuilder(
                future: _apiService.getMarketPriceHistory(
                  commodity: item.commodity,
                  state: item.state != 'N/A' ? item.state : null,
                  district: item.district != 'N/A' ? item.district : null,
                  limit: 20,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: AppColors.primary),
                          SizedBox(height: 12),
                          Text('Loading historical price trends...'),
                        ],
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error, size: 40),
                          const SizedBox(height: 8),
                          Text('Unable to load market price history: ${snapshot.error}'),
                        ],
                      ),
                    );
                  }

                  final data = snapshot.data?.data;
                  final List history = data != null && data['success'] == true ? (data['data'] ?? []) : [];
                  final dynamic prevRecord = history.length >= 2 ? history[history.length - 2] : null;
                  final double? prevPrice = (prevRecord != null && prevRecord['modalPrice'] != null)
                      ? (prevRecord['modalPrice'] as num).toDouble()
                      : null;
                  final double? pctChange = (prevPrice != null && prevPrice > 0)
                      ? (((item.modalPrice - prevPrice) / prevPrice) * 100.0)
                      : null;

                  return ListView(
                    controller: scrollController,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.commodity,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.market} Market (${item.district}, ${item.state})',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          Chip(
                            label: Text(
                              '${item.variety} • ${item.grade}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: const Color(0xFFDCFCE7),
                          ),
                        ],
                      ),
                      if (prevPrice != null && pctChange != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: pctChange >= 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: pctChange >= 0 ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Current: ₹${item.modalPrice.toStringAsFixed(0)} / Quintal',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: pctChange >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${pctChange >= 0 ? '↑ +' : '↓ '}${pctChange.toStringAsFixed(1)}%',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Previous: ₹${prevPrice.toStringAsFixed(0)} / Quintal',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              if (pctChange.abs() >= 5.0) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.notifications_active, size: 14, color: pctChange >= 0 ? Colors.green.shade800 : Colors.red.shade800),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Price change ≥ 5% triggers automatic ±5% market alerts to relevant farmers & buyers.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: pctChange >= 0 ? Colors.green.shade900 : Colors.red.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const Divider(height: 24),
                      // Key Metrics Summary
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _PriceColumn(
                              label: 'Latest Modal',
                              price: '₹${item.modalPrice.toStringAsFixed(0)}',
                              color: AppColors.primary,
                              isFeatured: true,
                            ),
                            _PriceColumn(
                              label: 'Min Price',
                              price: '₹${item.minPrice.toStringAsFixed(0)}',
                              color: AppColors.textSecondary,
                            ),
                            _PriceColumn(
                              label: 'Max Price',
                              price: '₹${item.maxPrice.toStringAsFixed(0)}',
                              color: AppColors.secondary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Historical Price Log (${history.length} records)',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (history.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text('Market price unavailable for this history range.', style: TextStyle(color: AppColors.textMuted)),
                          ),
                        )
                      else
                        ...history.reversed.map((h) {
                          final date = h['date'] ?? 'N/A';
                          final modal = (h['modalPrice'] as num?)?.toDouble() ?? 0;
                          final min = (h['minPrice'] as num?)?.toDouble() ?? 0;
                          final max = (h['maxPrice'] as num?)?.toDouble() ?? 0;
                          final marketName = h['market'] ?? item.market;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text(marketName, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('₹${modal.toStringAsFixed(0)}/Q', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 14)),
                                    Text('₹${min.toStringAsFixed(0)} - ₹${max.toStringAsFixed(0)}', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  );
                },
              ),
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
        title: const Text('Market Reference Prices'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchMarketPrices(page: _currentPage),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter & Search Header Card
          Card(
            margin: const EdgeInsets.all(AppConstants.paddingSmall),
            elevation: AppConstants.cardElevation,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingSmall),
              child: Column(
                children: [
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search commodity, market, or district...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _applyFilter();
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                    onSubmitted: (_) => _applyFilter(),
                  ),
                  const SizedBox(height: 8),

                  // Category Filter Horizontal Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((cat) {
                        final isSelected = _selectedCategory == cat['id'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(cat['name']!),
                            selected: isSelected,
                            selectedColor: AppColors.primary.withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? AppColors.primary : AppColors.textSecondary,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedCategory = cat['id']!;
                                  _selectedCommodity = null;
                                });
                                _applyFilter();
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Dropdown Filters
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedCommodity,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Commodity',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          items: _commodities.map((c) {
                            return DropdownMenuItem<String>(
                              value: c,
                              child: Text(c, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedCommodity = val;
                            });
                            _applyFilter();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedState,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'State',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          items: _states.map((s) {
                            return DropdownMenuItem<String>(
                              value: s,
                              child: Text(s, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedState = val;
                            });
                            _applyFilter();
                          },
                        ),
                      ),
                      if (_selectedCommodity != null || _selectedState != null || _searchController.text.isNotEmpty || _selectedCategory != 'all')
                        IconButton(
                          icon: const Icon(Icons.filter_alt_off, color: AppColors.error),
                          tooltip: 'Clear Filters',
                          onPressed: _clearFilters,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Total Records Badge
          if (!_isLoading && _errorMessage == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$_totalRecords records found',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    'Page $_currentPage of $_totalPages',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),

          // Main Body Content
          Expanded(
            child: _buildBody(),
          ),

          // Pagination Footer Bar
          if (!_isLoading && _errorMessage == null && _totalPages > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: _currentPage > 1 ? () => _fetchMarketPrices(page: _currentPage - 1) : null,
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Previous'),
                  ),
                  Text(
                    'Page $_currentPage of $_totalPages',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  OutlinedButton.icon(
                    onPressed: _currentPage < _totalPages ? () => _fetchMarketPrices(page: _currentPage + 1) : null,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('Next'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 12),
            Text('Loading AGMARKNET market prices...'),
          ],
        ),
      );
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
              Text(
                'Unable to load market prices',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
              ),
              const SizedBox(height: 4),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _fetchMarketPrices(page: _currentPage),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_prices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off, size: 56, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(
                'No market-price data found',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Try broadening your search term or clearing active filters.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _clearFilters,
                child: const Text('Clear Filters'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingSmall, vertical: 4),
      itemCount: _prices.length,
      itemBuilder: (context, index) {
        final item = _prices[index];
        return InkWell(
          onTap: () => _showTrendsModal(item),
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          child: Card(
            elevation: AppConstants.cardElevation,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Commodity Title & Grade/Variety Chip
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.commodity,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                      ),
                      Chip(
                        label: Text(
                          '${item.variety} • ${item.grade}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: const Color(0xFFDCFCE7),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Location & Market
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${item.market} Market (${item.district}, ${item.state})',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  // Price Grid
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _PriceColumn(
                        label: 'Min Price',
                        price: '₹${item.minPrice.toStringAsFixed(0)}',
                        color: AppColors.textSecondary,
                      ),
                      _PriceColumn(
                        label: 'Modal Price',
                        price: '₹${item.modalPrice.toStringAsFixed(0)}',
                        color: AppColors.primary,
                        isFeatured: true,
                      ),
                      _PriceColumn(
                        label: 'Max Price',
                        price: '₹${item.maxPrice.toStringAsFixed(0)}',
                        color: AppColors.secondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Date & Trends hint
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.show_chart, size: 14, color: AppColors.primary.withValues(alpha: 0.8)),
                          const SizedBox(width: 4),
                          Text(
                            'Tap to view historical trends',
                            style: TextStyle(
                              color: AppColors.primary.withValues(alpha: 0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Date: ${item.date}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
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
}

class _PriceColumn extends StatelessWidget {
  final String label;
  final String price;
  final Color color;
  final bool isFeatured;

  const _PriceColumn({
    required this.label,
    required this.price,
    required this.color,
    this.isFeatured = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: isFeatured ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          price,
          style: TextStyle(
            fontSize: isFeatured ? 16 : 14,
            fontWeight: isFeatured ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
        const Text(
          '/ Quintal',
          style: TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
