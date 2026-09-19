import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/buyer_requirement_model.dart';
import '../../providers/buyer_provider.dart';
import '../../services/api_service.dart';

class AddRequirementScreen extends StatefulWidget {
  final BuyerRequirementModel? initialRequirement;

  const AddRequirementScreen({super.key, this.initialRequirement});

  @override
  State<AddRequirementScreen> createState() => _AddRequirementScreenState();
}

class _AddRequirementScreenState extends State<AddRequirementScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form Fields
  String? _selectedCommodity;
  String? _selectedVariety;
  final TextEditingController _quantityController = TextEditingController();
  String _selectedUnit = 'quintal';
  final TextEditingController _priceController = TextEditingController();
  DateTime _requiredByDate = DateTime.now().add(const Duration(days: 7));
  String? _selectedState;
  String? _selectedDistrict;
  String? _selectedMarket;
  final TextEditingController _notesController = TextEditingController();

  // Dropdown lists
  List<String> _commodities = [];
  List<String> _varieties = [];
  List<String> _states = [];
  List<String> _districts = [];
  List<String> _markets = [];

  bool _isLoadingCatalog = true;
  bool _isSubmitting = false;

  // Market reference price tracking
  bool _isLoadingMarketPrice = false;
  double? _marketReferencePrice;
  String? _marketPriceDate;
  String? _marketPriceLocation;

  // ML Price Prediction tracking
  bool _isLoadingMlPrice = false;
  double? _mlPredictedPrice;
  double? _mlPredictedChangePercent;
  String? _mlTrend;

  late ApiService _apiService;

  bool get _isEditing => widget.initialRequirement != null;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();

    if (_isEditing) {
      final req = widget.initialRequirement!;
      _selectedCommodity = req.commodity;
      _selectedVariety = req.variety;
      _quantityController.text = req.quantity.toString();
      _selectedUnit = req.quantityUnit.toLowerCase();
      _priceController.text = req.offeredPrice.toString();
      _requiredByDate = req.requiredByDate;
      _selectedState = req.state;
      _selectedDistrict = req.district;
      _selectedMarket = req.market;
      _notesController.text = req.notes ?? '';
    }

    _loadInitialCatalog();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialCatalog() async {
    setState(() => _isLoadingCatalog = true);
    try {
      final commRes = await _apiService.getCommodities();
      final statesRes = await _apiService.getStates();

      if (commRes.data != null && commRes.data['success'] == true) {
        final List<dynamic> list = commRes.data['data'] ?? [];
        _commodities = list.map((e) => e.toString()).toList();
      }

      if (statesRes.data != null && statesRes.data['success'] == true) {
        final List<dynamic> list = statesRes.data['data'] ?? [];
        _states = list.map((e) => e.toString()).toList();
      }

      if (_selectedCommodity != null) {
        await _loadVarieties(_selectedCommodity!);
        await _fetchMarketReferencePrice(_selectedCommodity!);
      }
      if (_selectedState != null) {
        await _loadDistricts(_selectedState!);
      }
      if (_selectedDistrict != null) {
        await _loadMarkets(_selectedState, _selectedDistrict!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load catalog options: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingCatalog = false);
      }
    }
  }

  Future<void> _loadVarieties(String commodity) async {
    try {
      final varRes = await _apiService.getVarieties(commodity: commodity);
      if (mounted && varRes.data != null && varRes.data['success'] == true) {
        final List<dynamic> list = varRes.data['data'] ?? [];
        setState(() {
          _varieties = list.map((e) => e.toString()).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadDistricts(String state) async {
    try {
      final res = await _apiService.getDistricts(state: state);
      if (mounted && res.data != null && res.data['success'] == true) {
        final List<dynamic> list = res.data['data'] ?? [];
        setState(() {
          _districts = list.map((e) => e.toString()).toList();
          _markets = [];
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMarkets(String? state, String district) async {
    try {
      final res =
          await _apiService.getMarkets(state: state, district: district);
      if (mounted && res.data != null && res.data['success'] == true) {
        final List<dynamic> list = res.data['data'] ?? [];
        setState(() {
          _markets = list.map((e) => e.toString()).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchMarketReferencePrice(String commodity) async {
    setState(() {
      _isLoadingMarketPrice = true;
      _marketReferencePrice = null;
      _marketPriceDate = null;
      _marketPriceLocation = null;
    });

    _fetchMlPrice(commodity);

    try {
      final res = await _apiService.getReferenceMarketPrice(
        commodity: commodity,
        state: _selectedState,
        district: _selectedDistrict,
        market: _selectedMarket,
      );

      if (mounted && res.data != null && res.data['success'] == true) {
        final data = res.data['data'];
        if (data != null && data['referencePrice'] != null) {
          setState(() {
            _marketReferencePrice = (data['referencePrice'] as num).toDouble();
            _marketPriceDate = data['date'];
            _marketPriceLocation = data['market'] != null
                ? '${data['market']}, ${data['district'] ?? ''}'
                : data['state'];
          });
        }
      }
    } catch (_) {
      // Market price may be unavailable for new commodities
    } finally {
      if (mounted) {
        setState(() => _isLoadingMarketPrice = false);
      }
    }
  }

  Future<void> _fetchMlPrice(String commodity) async {
    setState(() {
      _isLoadingMlPrice = true;
      _mlPredictedPrice = null;
      _mlPredictedChangePercent = null;
      _mlTrend = null;
    });

    try {
      final res = await _apiService.getMarketPrediction(
        commodity: commodity,
        state: _selectedState,
        district: _selectedDistrict,
        market: _selectedMarket,
        variety: _selectedVariety,
      );

      if (mounted && res.data != null && res.data['success'] == true) {
        final data = res.data['data'];
        if (data != null && data['predictedPrice'] != null) {
          setState(() {
            _mlPredictedPrice = (data['predictedPrice'] as num).toDouble();
            _mlPredictedChangePercent =
                (data['predictedChangePercent'] as num?)?.toDouble();
            _mlTrend = data['trend'] as String?;
          });
        }
      }
    } catch (_) {
      // ML service may be offline or unavailable
    } finally {
      if (mounted) {
        setState(() => _isLoadingMlPrice = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _requiredByDate.isBefore(DateTime.now())
          ? DateTime.now().add(const Duration(days: 1))
          : _requiredByDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _requiredByDate = picked);
    }
  }

  void _showMarketPricesModal() async {
    if (_selectedCommodity == null || _selectedCommodity!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a crop.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            return FutureBuilder(
              future: _apiService.getMarketPrices(
                commodity: _selectedCommodity,
                state: _selectedState,
                limit: 10,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                          'Error loading market prices: ${snapshot.error}'),
                    ),
                  );
                }

                final data = snapshot.data?.data;
                final List<dynamic> prices =
                    data != null && data['success'] == true
                        ? (data['data'] ?? [])
                        : [];

                if (prices.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                          'No historical market price data found for this crop.'),
                    ),
                  );
                }

                return ListView.builder(
                  controller: controller,
                  padding: const EdgeInsets.all(16),
                  itemCount: prices.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Market Reference Prices for $_selectedCommodity',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const Text(
                              'Historical AGMARKNET rates for reference only.',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const Divider(),
                          ],
                        ),
                      );
                    }
                    final item = prices[index - 1];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                            '${item['market'] ?? 'Market'}, ${item['state'] ?? ''}'),
                        subtitle: Text(
                            'Variety: ${item['variety'] ?? 'FAQ'} • Date: ${item['date'] ?? ''}'),
                        trailing: Text(
                          '₹${item['modalPrice'] ?? 'N/A'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _submitForm() async {
    if (_selectedCommodity == null || _selectedCommodity!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a crop.')),
      );
      return;
    }

    if (_quantityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the required quantity.')),
      );
      return;
    }

    if (_priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your expected price.')),
      );
      return;
    }

    if (_selectedState == null ||
        _selectedState!.isEmpty ||
        _selectedDistrict == null ||
        _selectedDistrict!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the location.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final provider = Provider.of<BuyerProvider>(context, listen: false);
    final reqData = {
      'commodity': _selectedCommodity,
      'cropName': _selectedCommodity,
      'variety': _selectedVariety ?? 'Not specified',
      'quantity': double.parse(_quantityController.text.trim()),
      'quantityUnit': _selectedUnit,
      'offeredPrice': double.parse(_priceController.text.trim()),
      'requiredByDate': _requiredByDate.toIso8601String().split('T')[0],
      'state': _selectedState,
      'district': _selectedDistrict,
      'market': _selectedMarket ?? '',
      'location': _selectedMarket != null && _selectedMarket!.isNotEmpty
          ? _selectedMarket
          : _selectedDistrict,
      'notes': _notesController.text.trim(),
    };

    if (_isEditing) {
      final updated = await provider.updateRequirement(
          widget.initialRequirement!.id, reqData);
      setState(() => _isSubmitting = false);
      if (mounted) {
        if (updated != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Requirement updated successfully!')),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(provider.errorMessage ??
                    'Unable to submit your requirement.')),
          );
        }
      }
    } else {
      final created = await provider.createRequirement(reqData);
      setState(() => _isSubmitting = false);
      if (mounted) {
        if (created != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Requirement posted successfully!')),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(provider.errorMessage ??
                    'Unable to submit your requirement.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final expectedPriceValue = double.tryParse(_priceController.text.trim());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Requirement' : 'Post Requirement'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoadingCatalog
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Crop Selection
                    Text(
                      'Crop *',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _commodities.contains(_selectedCommodity)
                          ? _selectedCommodity
                          : null,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        hintText: 'Select Crop',
                        prefixIcon: Icon(Icons.eco_outlined,
                            color: AppColors.secondary),
                      ),
                      items: _commodities.map((c) {
                        return DropdownMenuItem(value: c, child: Text(c));
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedCommodity = val;
                          _selectedVariety = null;
                        });
                        if (val != null) {
                          _loadVarieties(val);
                          _fetchMarketReferencePrice(val);
                        }
                      },
                      validator: (val) => val == null || val.isEmpty
                          ? 'Please select a crop.'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // Variety (Optional)
                    Text(
                      'Variety (Optional)',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _varieties.contains(_selectedVariety)
                          ? _selectedVariety
                          : null,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        hintText: 'Select Variety',
                      ),
                      items: _varieties.isEmpty
                          ? [
                              const DropdownMenuItem(
                                  value: 'Standard/Other',
                                  child: Text('Standard/Other'))
                            ]
                          : _varieties
                              .map((v) =>
                                  DropdownMenuItem(value: v, child: Text(v)))
                              .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedVariety = val),
                    ),
                    const SizedBox(height: 12),

                    // Market Reference Price & Comparison Card
                    if (_selectedCommodity != null) ...[
                      Card(
                        color: const Color(0xFFEFF6FF),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppConstants.borderRadius),
                          side: const BorderSide(color: Color(0xFFBFDBFE)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.trending_up,
                                      color: Color(0xFF2563EB), size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Market Reference Price',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF1E40AF),
                                        ),
                                  ),
                                  const Spacer(),
                                  if (_isLoadingMarketPrice)
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  else
                                    TextButton(
                                      onPressed: _showMarketPricesModal,
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(40, 24),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text('View Trends',
                                          style: TextStyle(fontSize: 12)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (_marketReferencePrice != null) ...[
                                Text(
                                  'Selected Crop: $_selectedCommodity',
                                  style: const TextStyle(
                                      fontSize: 13, color: Color(0xFF1E3A8A)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Current Market Reference Price: ₹${_marketReferencePrice!.toStringAsFixed(0)} / Quintal',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                ),
                                if (_marketPriceLocation != null ||
                                    _marketPriceDate != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    [
                                      if (_marketPriceLocation != null)
                                        'Location: $_marketPriceLocation',
                                      if (_marketPriceDate != null)
                                        'Date: $_marketPriceDate',
                                    ].join(' • '),
                                    style: const TextStyle(
                                        fontSize: 11, color: Color(0xFF3B82F6)),
                                  ),
                                ],
                                if (_isLoadingMlPrice) ...[
                                  const SizedBox(height: 8),
                                  const Row(
                                    children: [
                                      SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color(0xFF7C3AED))),
                                      SizedBox(width: 6),
                                      Text('Generating ML price prediction...',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF7C3AED))),
                                    ],
                                  ),
                                ] else if (_mlPredictedPrice != null) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5F3FF),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: const Color(0xFFDDD6FE)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.auto_graph,
                                                size: 14,
                                                color: Color(0xFF7C3AED)),
                                            const SizedBox(width: 6),
                                            Text(
                                              'ML Predicted Price: ₹${_mlPredictedPrice!.toStringAsFixed(0)} / Quintal',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF6D28D9)),
                                            ),
                                          ],
                                        ),
                                        if (_mlPredictedChangePercent != null)
                                          Text(
                                            '${_mlPredictedChangePercent! >= 0 ? '+' : ''}${_mlPredictedChangePercent!.toStringAsFixed(1)}%${_mlTrend != null ? ' • $_mlTrend' : ''}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  _mlPredictedChangePercent! >=
                                                          0
                                                      ? const Color(0xFF166534)
                                                      : const Color(0xFF991B1B),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (expectedPriceValue != null &&
                                    expectedPriceValue > 0) ...[
                                  const Divider(height: 14),
                                  Text(
                                    'Your Expected Price: ₹${expectedPriceValue.toStringAsFixed(0)} / Quintal',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'ℹ Reference only — your entered price will not be automatically changed.',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary),
                                  ),
                                ],
                              ] else if (!_isLoadingMarketPrice) ...[
                                const Text(
                                  'Market price unavailable for this specific selection.',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Quantity and Unit
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quantity (Quintals) *',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _quantityController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  hintText: 'e.g. 50',
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Please enter the required quantity.';
                                  }
                                  final num = double.tryParse(val.trim());
                                  if (num == null || num <= 0) {
                                    return 'Quantity must be > 0';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Unit *',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedUnit,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'quintal', child: Text('Quintal')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedUnit = val);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Expected Price
                    Text(
                      'Expected Price (₹ / Quintal) *',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _priceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        hintText: 'e.g. 2200',
                        prefixText: '₹ ',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.analytics_outlined,
                              color: AppColors.secondary),
                          tooltip: 'View Market Reference Prices',
                          onPressed: _showMarketPricesModal,
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter your expected price.';
                        }
                        final num = double.tryParse(val.trim());
                        if (num == null || num < 0) return 'Price must be >= 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Required By Date
                    Text(
                      'Required Date *',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _selectDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          '${_requiredByDate.day.toString().padLeft(2, '0')}/${_requiredByDate.month.toString().padLeft(2, '0')}/${_requiredByDate.year}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Location - State & District
                    Text(
                      'Location (State & District) *',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _states.contains(_selectedState)
                          ? _selectedState
                          : null,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        hintText: 'Select State *',
                      ),
                      items: _states
                          .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedState = val;
                          _selectedDistrict = null;
                          _selectedMarket = null;
                          _districts = [];
                          _markets = [];
                        });
                        if (val != null) {
                          _loadDistricts(val);
                          if (_selectedCommodity != null) {
                            _fetchMarketReferencePrice(_selectedCommodity!);
                          }
                        }
                      },
                      validator: (val) => val == null || val.isEmpty
                          ? 'Please enter the location.'
                          : null,
                    ),
                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      initialValue: _districts.contains(_selectedDistrict)
                          ? _selectedDistrict
                          : null,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        hintText: 'Select District *',
                      ),
                      items: _districts
                          .map(
                              (d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedDistrict = val;
                          _selectedMarket = null;
                          _markets = [];
                        });
                        if (val != null) {
                          _loadMarkets(_selectedState, val);
                          if (_selectedCommodity != null) {
                            _fetchMarketReferencePrice(_selectedCommodity!);
                          }
                        }
                      },
                      validator: (val) => val == null || val.isEmpty
                          ? 'Please enter the location.'
                          : null,
                    ),
                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      initialValue: _markets.contains(_selectedMarket)
                          ? _selectedMarket
                          : null,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        hintText: 'Select Specific Market/Mandi (Optional)',
                      ),
                      items: _markets
                          .map(
                              (m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (val) {
                        setState(() => _selectedMarket = val);
                        if (_selectedCommodity != null) {
                          _fetchMarketReferencePrice(_selectedCommodity!);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Notes (Optional)
                    Text(
                      'Notes (Optional, max 500 chars)',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Add additional requirement notes...',
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button: Post Requirement
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppConstants.borderRadius),
                          ),
                        ),
                        onPressed: _isSubmitting ? null : _submitForm,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                _isEditing
                                    ? 'Update Requirement'
                                    : 'Post Requirement',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
