import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/crop_model.dart';
import '../../services/api_service.dart';
import '../../widgets/farm_badge.dart';
import '../../widgets/farm_card.dart';

class AddCropScreen extends StatefulWidget {
  final CropModel? initialCrop;

  const AddCropScreen({super.key, this.initialCrop});

  @override
  State<AddCropScreen> createState() => _AddCropScreenState();
}

class _AddCropScreenState extends State<AddCropScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  bool _isSubmitting = false;
  String? _errorMessage;

  List<String> _commodities = [];
  List<String> _varieties = [];
  List<String> _states = [];
  List<String> _districts = [];
  List<String> _markets = [];

  String? _selectedCommodity;
  final TextEditingController _cropNameController = TextEditingController();
  String? _selectedVariety;
  final TextEditingController _quantityController = TextEditingController();
  String _selectedUnit = 'quintal';
  final TextEditingController _expectedPriceController =
      TextEditingController();
  DateTime? _selectedHarvestDate;
  String? _selectedState;
  String? _selectedDistrict;
  String? _selectedMarket;
  final TextEditingController _descriptionController = TextEditingController();

  // Live Market Reference Price state
  bool _isLoadingMarketRate = false;
  Map<String, dynamic>? _marketRateData;
  bool _marketRateUnavailable = false;

  // ML Price Prediction state
  bool _isLoadingMlRate = false;
  Map<String, dynamic>? _mlRateData;

  bool get _isEditMode => widget.initialCrop != null;

  @override
  void initState() {
    super.initState();
    _loadInitialCatalogs();
    if (_isEditMode) {
      _prefillExistingData();
    }
  }

  void _prefillExistingData() {
    final crop = widget.initialCrop!;
    _selectedCommodity = crop.commodity;
    _cropNameController.text = crop.cropName;
    _selectedVariety = crop.variety;
    _quantityController.text = crop.quantity.toString();
    _selectedUnit = crop.quantityUnit;
    _expectedPriceController.text =
        (crop.expectedPrice != null && crop.expectedPrice! > 0)
            ? crop.expectedPrice!.toString()
            : '';
    _selectedHarvestDate = crop.harvestDate;
    _selectedState = crop.state;
    _selectedDistrict = crop.district;
    _selectedMarket = crop.market;
    _descriptionController.text = crop.description ?? '';
    _fetchMarketRate();
  }

  @override
  void dispose() {
    _cropNameController.dispose();
    _quantityController.dispose();
    _expectedPriceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialCatalogs() async {
    try {
      final results = await Future.wait([
        _apiService.getCommodities(),
        _apiService.getStates(),
      ]);

      if (mounted) {
        setState(() {
          if (results[0].data != null && results[0].data['success'] == true) {
            _commodities = List<String>.from(results[0].data['data']);
          }
          if (results[1].data != null && results[1].data['success'] == true) {
            _states = List<String>.from(results[1].data['data']);
          }
        });
      }

      if (_selectedCommodity != null) {
        _onCommodityChanged(_selectedCommodity, isInit: true);
      }
      if (_selectedState != null) {
        _onStateChanged(_selectedState, isInit: true);
      }
    } catch (_) {}
  }

  Future<void> _fetchMarketRate() async {
    final comm = _selectedCommodity ?? _cropNameController.text.trim();
    if (comm.isEmpty) {
      setState(() {
        _marketRateData = null;
        _marketRateUnavailable = false;
        _isLoadingMarketRate = false;
        _mlRateData = null;
        _isLoadingMlRate = false;
      });
      return;
    }

    setState(() {
      _isLoadingMarketRate = true;
      _marketRateUnavailable = false;
      _marketRateData = null;
    });

    _fetchMlRate();

    try {
      final res = await _apiService.getReferenceMarketPrice(
        commodity: comm,
        state: _selectedState,
        district: _selectedDistrict,
        market: _selectedMarket,
      );

      if (mounted) {
        if (res.data != null &&
            res.data['success'] == true &&
            res.data['data'] != null) {
          setState(() {
            _marketRateData = res.data['data'];
            _isLoadingMarketRate = false;
            _marketRateUnavailable = false;
          });
        } else {
          setState(() {
            _isLoadingMarketRate = false;
            _marketRateUnavailable = true;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingMarketRate = false;
          _marketRateUnavailable = true;
        });
      }
    }
  }

  Future<void> _fetchMlRate() async {
    final comm = _selectedCommodity ?? _cropNameController.text.trim();
    if (comm.isEmpty) return;

    setState(() {
      _isLoadingMlRate = true;
      _mlRateData = null;
    });

    try {
      final res = await _apiService.getMarketPrediction(
        commodity: comm,
        state: _selectedState,
        district: _selectedDistrict,
        market: _selectedMarket,
      );

      if (mounted) {
        if (res.data != null &&
            res.data['success'] == true &&
            res.data['data'] != null) {
          setState(() {
            _mlRateData = res.data['data'];
            _isLoadingMlRate = false;
          });
        } else {
          setState(() {
            _isLoadingMlRate = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingMlRate = false;
        });
      }
    }
  }

  Future<void> _onCommodityChanged(String? commodity,
      {bool isInit = false}) async {
    if (commodity == null) return;
    setState(() {
      _selectedCommodity = commodity;
      if (!isInit && _cropNameController.text.isEmpty) {
        _cropNameController.text = commodity;
      }
      if (!isInit) {
        _selectedVariety = null;
      }
    });

    _fetchMarketRate();

    try {
      final res = await _apiService.getVarieties(commodity: commodity);
      if (mounted && res.data != null && res.data['success'] == true) {
        setState(() {
          _varieties = List<String>.from(res.data['data']);
        });
      }
    } catch (_) {}
  }

  Future<void> _onStateChanged(String? state, {bool isInit = false}) async {
    if (state == null) return;
    setState(() {
      _selectedState = state;
      if (!isInit) {
        _selectedDistrict = null;
        _selectedMarket = null;
        _districts = [];
        _markets = [];
      }
    });

    _fetchMarketRate();

    try {
      final res = await _apiService.getDistricts(state: state);
      if (mounted && res.data != null && res.data['success'] == true) {
        setState(() {
          _districts = List<String>.from(res.data['data']);
        });
      }
    } catch (_) {}
  }

  Future<void> _onDistrictChanged(String? district) async {
    if (district == null) return;
    setState(() {
      _selectedDistrict = district;
      _selectedMarket = null;
      _markets = [];
    });

    _fetchMarketRate();

    try {
      final res = await _apiService.getMarkets(
          state: _selectedState, district: district);
      if (mounted && res.data != null && res.data['success'] == true) {
        setState(() {
          _markets = List<String>.from(res.data['data']);
        });
      }
    } catch (_) {}
  }

  Future<void> _selectHarvestDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedHarvestDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() {
        _selectedHarvestDate = picked;
      });
    }
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedHarvestDate == null) {
      setState(() {
        _errorMessage = 'Please select an expected harvest date';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final payload = {
      'commodity': _selectedCommodity ?? _cropNameController.text.trim(),
      'cropName': _cropNameController.text.trim(),
      'variety': _selectedVariety ?? 'Other',
      'quantity': double.parse(_quantityController.text.trim()),
      'quantityUnit': _selectedUnit,
      'expectedPrice': _expectedPriceController.text.isNotEmpty
          ? double.parse(_expectedPriceController.text.trim())
          : 0,
      'harvestDate': _selectedHarvestDate!.toIso8601String().split('T')[0],
      'state': _selectedState,
      'district': _selectedDistrict,
      'market': _selectedMarket ?? '',
      'location': _selectedMarket ?? _selectedDistrict ?? '',
      'description': _descriptionController.text.trim(),
    };

    try {
      if (_isEditMode) {
        await _apiService.updateCrop(widget.initialCrop!.id, payload);
      } else {
        await _apiService.createCrop(payload);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_isEditMode
                ? 'Crop updated successfully'
                : 'Crop added successfully')),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Widget _buildMarketRateCard() {
    final commName = _selectedCommodity ?? _cropNameController.text.trim();
    if (commName.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.trending_up, color: AppColors.primary, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Market Reference Price',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.primaryDark),
                  ),
                ],
              ),
              FarmBadge(
                  label: commName, type: FarmBadgeType.primary, fontSize: 10),
            ],
          ),
          const SizedBox(height: 8),
          if (_isLoadingMarketRate)
            const Row(
              children: [
                SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary)),
                SizedBox(width: 10),
                Text('Fetching live AGMARKNET rate...',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            )
          else if (_marketRateUnavailable || _marketRateData == null)
            const Text(
                'Market price data currently unavailable for this mandi.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted))
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current Modal Rate',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                    Text(
                      '₹${(_marketRateData!['modalPrice'] as num).toStringAsFixed(0)} / ${_marketRateData!['unit'] ?? 'Quintal'}',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                    ),
                  ],
                ),
                if (_marketRateData!['minPrice'] != null &&
                    _marketRateData!['maxPrice'] != null)
                  Text(
                    'Range: ₹${_marketRateData!['minPrice']} - ₹${_marketRateData!['maxPrice']}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
              ],
            ),
            if (_isLoadingMlRate) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.secondary)),
                  SizedBox(width: 8),
                  Text('Calculating ML predicted price...',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ] else if (_mlRateData != null &&
                _mlRateData!['predictedPrice'] != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ML Forecast Rate: ₹${(_mlRateData!['predictedPrice'] as num).toStringAsFixed(0)} / Quintal',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary),
                  ),
                  if (_mlRateData!['predictedChangePercent'] != null)
                    FarmBadge(
                      label:
                          '${(_mlRateData!['predictedChangePercent'] as num) >= 0 ? "+" : ""}${(_mlRateData!['predictedChangePercent'] as num).toStringAsFixed(1)}%',
                      type: (_mlRateData!['predictedChangePercent'] as num) >= 0
                          ? FarmBadgeType.success
                          : FarmBadgeType.error,
                      fontSize: 10,
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Crop' : 'Add New Crop'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                                color: AppColors.errorDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // SECTION 1: CROP DETAILS (White Card)
                FarmCard(
                  variant: FarmCardVariant.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.grass, color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text(
                            '1. Crop Information',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const Divider(height: 18),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCommodity,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Commodity *',
                          prefixIcon: Icon(Icons.eco_outlined, size: 20),
                        ),
                        items: _commodities
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: _isSubmitting
                            ? null
                            : (val) => _onCommodityChanged(val),
                        validator: (val) {
                          if ((val == null || val.isEmpty) &&
                              _cropNameController.text.trim().isEmpty) {
                            return 'Please select a commodity';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildMarketRateCard(),
                      TextFormField(
                        controller: _cropNameController,
                        enabled: !_isSubmitting,
                        decoration: const InputDecoration(
                          labelText: 'Listing Title / Crop Name *',
                          prefixIcon: Icon(Icons.title, size: 20),
                        ),
                        onChanged: (_) => _fetchMarketRate(),
                        validator: (val) => (val == null || val.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedVariety,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Variety (Optional)',
                          prefixIcon: Icon(Icons.category_outlined, size: 20),
                        ),
                        items: (_varieties.isEmpty
                                ? ['Other', 'Local', 'Hybrid', 'Desi']
                                : _varieties)
                            .map((v) => DropdownMenuItem(
                                value: v,
                                child:
                                    Text(v, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: _isSubmitting
                            ? null
                            : (val) => setState(() => _selectedVariety = val),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // SECTION 2: QUANTITY & HARVEST (White Card)
                FarmCard(
                  variant: FarmCardVariant.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.scale, color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text(
                            '2. Quantity & Expected Price',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const Divider(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _quantityController,
                              enabled: !_isSubmitting,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Quantity *',
                                prefixIcon:
                                    Icon(Icons.scale_outlined, size: 20),
                                hintText: 'e.g. 50',
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Required';
                                }
                                final d = double.tryParse(val.trim());
                                if (d == null || d <= 0) return '> 0';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedUnit,
                              decoration:
                                  const InputDecoration(labelText: 'Unit *'),
                              items: const [
                                DropdownMenuItem(
                                    value: 'quintal', child: Text('Quintal'))
                              ],
                              onChanged: _isSubmitting
                                  ? null
                                  : (val) =>
                                      setState(() => _selectedUnit = val!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _expectedPriceController,
                        enabled: !_isSubmitting,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Expected Price (₹ / Quintal)',
                          prefixIcon: Icon(Icons.currency_rupee, size: 20),
                          hintText: 'e.g. 2400',
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _isSubmitting ? null : _selectHarvestDate,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Harvest / Availability Date *',
                            prefixIcon:
                                Icon(Icons.calendar_today_outlined, size: 20),
                          ),
                          child: Text(
                            _selectedHarvestDate != null
                                ? _selectedHarvestDate!
                                    .toIso8601String()
                                    .split('T')[0]
                                : 'Select Date',
                            style: TextStyle(
                              color: _selectedHarvestDate != null
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // SECTION 3: LOCATION DETAILS (White Card)
                FarmCard(
                  variant: FarmCardVariant.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.location_on,
                              color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text(
                            '3. Farm Location & Mandi',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const Divider(height: 18),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedState,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'State *',
                          prefixIcon: Icon(Icons.map_outlined, size: 20),
                        ),
                        items: _states
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: _isSubmitting
                            ? null
                            : (val) => _onStateChanged(val),
                        validator: (val) => (val == null || val.isEmpty)
                            ? 'State is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedDistrict,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'District *',
                          prefixIcon:
                              Icon(Icons.location_city_outlined, size: 20),
                        ),
                        items: _districts
                            .map((d) =>
                                DropdownMenuItem(value: d, child: Text(d)))
                            .toList(),
                        onChanged: _isSubmitting
                            ? null
                            : (val) => _onDistrictChanged(val),
                        validator: (val) => (val == null || val.isEmpty)
                            ? 'District is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedMarket,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Nearest Mandi / APMC Yard (Optional)',
                          prefixIcon: Icon(Icons.storefront_outlined, size: 20),
                        ),
                        items: _markets
                            .map((m) =>
                                DropdownMenuItem(value: m, child: Text(m)))
                            .toList(),
                        onChanged: _isSubmitting
                            ? null
                            : (val) {
                                setState(() => _selectedMarket = val);
                                _fetchMarketRate();
                              },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        enabled: !_isSubmitting,
                        maxLength: 500,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Additional Notes (Optional)',
                          alignLabelWithHint: true,
                          hintText:
                              'Quality specifics, packaging, moisture level...',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Submit Button
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          _isEditMode ? 'Save Changes' : 'List Crop Produce',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
