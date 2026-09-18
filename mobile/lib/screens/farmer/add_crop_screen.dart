import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/crop_model.dart';
import '../../services/api_service.dart';

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
  String _selectedUnit = 'kg';
  final TextEditingController _expectedPriceController = TextEditingController();
  DateTime? _selectedHarvestDate;
  String? _selectedState;
  String? _selectedDistrict;
  String? _selectedMarket;
  final TextEditingController _descriptionController = TextEditingController();

  // Live Market Reference Price state
  bool _isLoadingMarketRate = false;
  Map<String, dynamic>? _marketRateData;
  bool _marketRateUnavailable = false;

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
    _expectedPriceController.text = (crop.expectedPrice != null && crop.expectedPrice! > 0)
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
    } catch (_) {
      // Handled gracefully
    }
  }

  Future<void> _fetchMarketRate() async {
    final comm = _selectedCommodity ?? _cropNameController.text.trim();
    if (comm.isEmpty) {
      setState(() {
        _marketRateData = null;
        _marketRateUnavailable = false;
        _isLoadingMarketRate = false;
      });
      return;
    }

    setState(() {
      _isLoadingMarketRate = true;
      _marketRateUnavailable = false;
      _marketRateData = null;
    });

    try {
      final res = await _apiService.getReferenceMarketPrice(
        commodity: comm,
        state: _selectedState,
        district: _selectedDistrict,
        market: _selectedMarket,
      );

      if (mounted) {
        if (res.data != null && res.data['success'] == true && res.data['data'] != null) {
          setState(() {
            _marketRateData = res.data['data'];
            _marketRateUnavailable = false;
            _isLoadingMarketRate = false;
          });
        } else {
          setState(() {
            _marketRateData = null;
            _marketRateUnavailable = true;
            _isLoadingMarketRate = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _marketRateData = null;
          _marketRateUnavailable = true;
          _isLoadingMarketRate = false;
        });
      }
    }
  }

  Future<void> _onCommodityChanged(String? commodity, {bool isInit = false}) async {
    if (!isInit) {
      setState(() {
        _selectedCommodity = commodity;
        _selectedVariety = null;
        if (commodity != null && _cropNameController.text.isEmpty) {
          _cropNameController.text = commodity;
        }
      });
    }

    _fetchMarketRate();

    if (commodity == null || commodity.isEmpty) return;

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
    if (!isInit) {
      setState(() {
        _selectedState = state;
        _selectedDistrict = null;
        _selectedMarket = null;
        _districts = [];
        _markets = [];
      });
    }

    _fetchMarketRate();

    if (state == null || state.isEmpty) return;

    try {
      final res = await _apiService.getDistricts(state: state);
      if (mounted && res.data != null && res.data['success'] == true) {
        setState(() {
          _districts = List<String>.from(res.data['data']);
        });
      }
      if (_selectedDistrict != null) {
        _onDistrictChanged(_selectedDistrict, isInit: true);
      }
    } catch (_) {}
  }

  Future<void> _onDistrictChanged(String? district, {bool isInit = false}) async {
    if (!isInit) {
      setState(() {
        _selectedDistrict = district;
        _selectedMarket = null;
        _markets = [];
      });
    }

    _fetchMarketRate();

    if (district == null || district.isEmpty) return;

    try {
      final res = await _apiService.getMarkets(state: _selectedState, district: district);
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
        _errorMessage = 'Please select a harvest date';
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
        SnackBar(content: Text(_isEditMode ? 'Crop updated successfully' : 'Crop added successfully')),
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

    return Card(
      elevation: 0,
      color: const Color(0xFFF0F9FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        side: const BorderSide(color: Color(0xFFBAE6FD)),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.trending_up, color: Color(0xFF0284C7), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Market Reference Price',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0369A1),
                          ),
                    ),
                  ],
                ),
                Chip(
                  label: Text(
                    commName,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                  ),
                  backgroundColor: const Color(0xFFE0F2FE),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const Divider(height: 16, color: Color(0xFFBAE6FD)),
            if (_isLoadingMarketRate)
              const Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7))),
                  SizedBox(width: 12),
                  Text('Fetching AGMARKNET market rate...', style: TextStyle(fontSize: 13, color: Color(0xFF0369A1))),
                ],
              )
            else if (_marketRateUnavailable || _marketRateData == null)
              const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppColors.textMuted),
                  SizedBox(width: 8),
                  Text('Market price unavailable', style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                ],
              )
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Market Rate',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${(_marketRateData!['modalPrice'] as num).toStringAsFixed(0)} / ${_marketRateData!['unit'] ?? 'Quintal'}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                  if (_marketRateData!['minPrice'] != null && _marketRateData!['maxPrice'] != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Range', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        Text(
                          '₹${(_marketRateData!['minPrice'] as num).toStringAsFixed(0)} - ₹${(_marketRateData!['maxPrice'] as num).toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                ],
              ),
              if (_marketRateData!['market'] != null && (_marketRateData!['market'] as String).isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Source: ${_marketRateData!['market']} Market (${_marketRateData!['district'] ?? ''}, ${_marketRateData!['state'] ?? ''})',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ],
        ),
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
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 1. Commodity Selection
                DropdownButtonFormField<String>(
                  initialValue: _selectedCommodity,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Commodity *',
                    prefixIcon: Icon(Icons.grass),
                  ),
                  items: _commodities.map((c) {
                    return DropdownMenuItem<String>(value: c, child: Text(c));
                  }).toList(),
                  onChanged: _isSubmitting ? null : (val) => _onCommodityChanged(val),
                  validator: (val) {
                    if ((val == null || val.isEmpty) && _cropNameController.text.trim().isEmpty) {
                      return 'Please select or enter a commodity';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Market Reference Price Display Card
                _buildMarketRateCard(),

                // Crop Name
                TextFormField(
                  controller: _cropNameController,
                  enabled: !_isSubmitting,
                  decoration: const InputDecoration(
                    labelText: 'Crop Name *',
                    prefixIcon: Icon(Icons.label_outlined),
                  ),
                  onChanged: (_) => _fetchMarketRate(),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Crop name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Variety Field (Grade REMOVED)
                DropdownButtonFormField<String>(
                  initialValue: _selectedVariety,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Variety (Optional)',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: (_varieties.isEmpty ? ['Other', 'Local', 'Hybrid', 'Desi'] : _varieties).map((v) {
                    return DropdownMenuItem<String>(value: v, child: Text(v, overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (val) {
                          setState(() {
                            _selectedVariety = val;
                          });
                        },
                ),
                const SizedBox(height: 16),

                // Quantity & Unit Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _quantityController,
                        enabled: !_isSubmitting,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Quantity *',
                          prefixIcon: Icon(Icons.scale_outlined),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Required';
                          }
                          final d = double.tryParse(val.trim());
                          if (d == null || d <= 0) {
                            return 'Must be > 0';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedUnit,
                        decoration: const InputDecoration(
                          labelText: 'Unit *',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'kg', child: Text('kg')),
                          DropdownMenuItem(value: 'quintal', child: Text('quintal')),
                          DropdownMenuItem(value: 'tonne', child: Text('tonne')),
                        ],
                        onChanged: _isSubmitting
                            ? null
                            : (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedUnit = val;
                                  });
                                }
                              },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Expected Selling Price
                TextFormField(
                  controller: _expectedPriceController,
                  enabled: !_isSubmitting,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Farmer Expected Price (₹ / Unit)',
                    prefixIcon: Icon(Icons.currency_rupee),
                    hintText: 'e.g. 2200',
                  ),
                  validator: (val) {
                    if (val != null && val.isNotEmpty) {
                      final d = double.tryParse(val.trim());
                      if (d == null || d < 0) {
                        return 'Price cannot be negative';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Harvest Date Picker Field
                InkWell(
                  onTap: _isSubmitting ? null : _selectHarvestDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Expected / Harvest Date *',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(
                      _selectedHarvestDate != null
                          ? _selectedHarvestDate!.toIso8601String().split('T')[0]
                          : 'Select Harvest Date',
                      style: TextStyle(
                        color: _selectedHarvestDate != null ? AppColors.textPrimary : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Location Dropdowns (State, District, Market)
                DropdownButtonFormField<String>(
                  initialValue: _selectedState,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'State *',
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                  items: _states.map((s) {
                    return DropdownMenuItem<String>(value: s, child: Text(s));
                  }).toList(),
                  onChanged: _isSubmitting ? null : (val) => _onStateChanged(val),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'State is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: _selectedDistrict,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'District *',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                  items: _districts.map((d) {
                    return DropdownMenuItem<String>(value: d, child: Text(d));
                  }).toList(),
                  onChanged: _isSubmitting ? null : (val) => _onDistrictChanged(val),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'District is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: _selectedMarket,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Market / Mandi',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                  items: _markets.map((m) {
                    return DropdownMenuItem<String>(value: m, child: Text(m));
                  }).toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (val) {
                          setState(() {
                            _selectedMarket = val;
                          });
                          _fetchMarketRate();
                        },
                ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  enabled: !_isSubmitting,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    alignLabelWithHint: true,
                    hintText: 'Additional details (quality notes, packaging, etc.)',
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          _isEditMode ? 'Save Changes' : 'Add Crop',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
