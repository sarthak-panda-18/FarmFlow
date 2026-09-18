const User = require('../models/User');
const Crop = require('../models/Crop');
const BuyerRequirement = require('../models/BuyerRequirement');
const MarketPrice = require('../models/MarketPrice');
const {
  calculateHaversineDistance,
  isValidCoordinates,
  buildGeoJsonPoint,
  buildGoogleMapsUrl,
} = require('../utils/geoUtils');
const { buildCommodityFilter } = require('../utils/commodityCategoryMapping');

/**
 * @desc    Update current user's GPS coordinates and location metadata
 * @route   PUT /api/location
 * @access  Private (Authenticated Farmer or Buyer)
 */
const updateMyLocation = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { latitude, longitude, address, city, district, state } = req.body;

    if (!isValidCoordinates(latitude, longitude)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid GPS coordinates. Latitude must be between -90 and 90, and Longitude between -180 and 180.',
      });
    }

    const numLat = Number(latitude);
    const numLng = Number(longitude);
    const geoPoint = buildGeoJsonPoint(numLng, numLat);

    const updateFields = {
      location: geoPoint,
    };

    if (address !== undefined) updateFields.address = String(address).trim();
    if (city !== undefined) updateFields.city = String(city).trim();
    if (district !== undefined) updateFields.district = String(district).trim();
    if (state !== undefined) updateFields.state = String(state).trim();

    const updatedUser = await User.findByIdAndUpdate(userId, updateFields, {
      new: true,
      runValidators: true,
    }).select('-passwordHash');

    if (!updatedUser) {
      return res.status(404).json({
        success: false,
        message: 'User account not found',
      });
    }

    // Propagate location coordinates to user's active crops or requirements
    if (updatedUser.role === 'FARMER') {
      await Crop.updateMany(
        { farmerId: userId },
        {
          locationCoordinates: geoPoint,
          ...(updateFields.district && { district: updateFields.district }),
          ...(updateFields.state && { state: updateFields.state }),
        }
      );
    } else if (updatedUser.role === 'BUYER') {
      await BuyerRequirement.updateMany(
        { buyerId: userId },
        {
          locationCoordinates: geoPoint,
          ...(updateFields.district && { district: updateFields.district }),
          ...(updateFields.state && { state: updateFields.state }),
        }
      );
    }

    res.status(200).json({
      success: true,
      message: 'Location updated successfully',
      data: {
        userId: updatedUser._id,
        role: updatedUser.role,
        latitude: numLat,
        longitude: numLng,
        address: updatedUser.address || '',
        city: updatedUser.city || '',
        district: updatedUser.district || '',
        state: updatedUser.state || '',
        googleMapsUrl: buildGoogleMapsUrl(numLat, numLng, updatedUser.name),
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get current user's location and address
 * @route   GET /api/location/me
 * @access  Private (Authenticated)
 */
const getMyLocation = async (req, res, next) => {
  try {
    const user = await User.findById(req.user.id).select('-passwordHash');
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found',
      });
    }

    let lat = null;
    let lng = null;
    if (
      user.location &&
      user.location.coordinates &&
      user.location.coordinates.length === 2
    ) {
      lng = user.location.coordinates[0];
      lat = user.location.coordinates[1];
    }

    res.status(200).json({
      success: true,
      data: {
        userId: user._id,
        name: user.name,
        role: user.role,
        hasCoordinates: lat !== null && lng !== null,
        latitude: lat,
        longitude: lng,
        address: user.address || '',
        city: user.city || '',
        district: user.district || '',
        state: user.state || '',
        googleMapsUrl: lat !== null && lng !== null ? buildGoogleMapsUrl(lat, lng, user.name) : '',
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get nearby Farmers and their available crops within distance radius
 * @route   GET /api/location/nearby-farmers
 * @access  Private
 */
const getNearbyFarmers = async (req, res, next) => {
  try {
    let { latitude, longitude, maxDistanceKm = 50, commodity, limit = 30 } = req.query;

    // Use logged in user's coordinates if not passed in query
    if (!latitude || !longitude) {
      const me = await User.findById(req.user.id).lean();
      if (me?.location?.coordinates?.length === 2) {
        longitude = me.location.coordinates[0];
        latitude = me.location.coordinates[1];
      }
    }

    if (!isValidCoordinates(latitude, longitude)) {
      return res.status(400).json({
        success: false,
        message: 'Valid latitude and longitude are required to search nearby farmers.',
      });
    }

    const numLat = Number(latitude);
    const numLng = Number(longitude);
    const maxDist = Math.min(500, Math.max(1, Number(maxDistanceKm) || 50));
    const maxMeters = maxDist * 1000;
    const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 30));

    // MongoDB 2dsphere $near query
    const nearbyFarmers = await User.find({
      role: 'FARMER',
      _id: { $ne: req.user.id },
      location: {
        $near: {
          $geometry: {
            type: 'Point',
            coordinates: [numLng, numLat],
          },
          $maxDistance: maxMeters,
        },
      },
    })
      .select('name location address city district state')
      .limit(limitNum)
      .lean();

    const farmerIds = nearbyFarmers.map((f) => f._id);

    // Fetch active crops for these nearby farmers
    const cropFilter = {
      farmerId: { $in: farmerIds },
      status: 'AVAILABLE',
    };
    if (commodity && commodity.trim()) {
      const commFilter = buildCommodityFilter(commodity.trim());
      if (commFilter) Object.assign(cropFilter, commFilter);
    }

    const activeCrops = await Crop.find(cropFilter).lean();

    const cropsByFarmer = {};
    for (const crop of activeCrops) {
      const fId = crop.farmerId.toString();
      if (!cropsByFarmer[fId]) cropsByFarmer[fId] = [];
      cropsByFarmer[fId].push({
        id: crop._id,
        commodity: crop.commodity,
        cropName: crop.cropName,
        variety: crop.variety,
        grade: crop.grade,
        quantity: crop.quantity,
        quantityUnit: crop.quantityUnit,
        expectedPrice: crop.expectedPrice,
        harvestDate: crop.harvestDate ? crop.harvestDate.toISOString().split('T')[0] : null,
      });
    }

    const results = nearbyFarmers
      .map((farmer) => {
        const [fLng, fLat] = farmer.location.coordinates;
        const distKm = calculateHaversineDistance(numLat, numLng, fLat, fLng);
        const farmerCrops = cropsByFarmer[farmer._id.toString()] || [];

        return {
          farmerId: farmer._id,
          name: farmer.name,
          latitude: fLat,
          longitude: fLng,
          address: farmer.address || '',
          district: farmer.district || '',
          state: farmer.state || '',
          distanceKm: distKm,
          cropCount: farmerCrops.length,
          crops: farmerCrops,
          googleMapsUrl: buildGoogleMapsUrl(fLat, fLng, `${farmer.name} (Farmer)`),
        };
      })
      .filter((f) => !commodity || f.cropCount > 0);

    // Sort ascending by distance
    results.sort((a, b) => a.distanceKm - b.distanceKm);

    res.status(200).json({
      success: true,
      origin: { latitude: numLat, longitude: numLng },
      maxDistanceKm: maxDist,
      count: results.length,
      data: results,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get nearby Buyers and their active requirements within distance radius
 * @route   GET /api/location/nearby-buyers
 * @access  Private
 */
const getNearbyBuyers = async (req, res, next) => {
  try {
    let { latitude, longitude, maxDistanceKm = 50, commodity, limit = 30 } = req.query;

    if (!latitude || !longitude) {
      const me = await User.findById(req.user.id).lean();
      if (me?.location?.coordinates?.length === 2) {
        longitude = me.location.coordinates[0];
        latitude = me.location.coordinates[1];
      }
    }

    if (!isValidCoordinates(latitude, longitude)) {
      return res.status(400).json({
        success: false,
        message: 'Valid latitude and longitude are required to search nearby buyers.',
      });
    }

    const numLat = Number(latitude);
    const numLng = Number(longitude);
    const maxDist = Math.min(500, Math.max(1, Number(maxDistanceKm) || 50));
    const maxMeters = maxDist * 1000;
    const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 30));

    const nearbyBuyers = await User.find({
      role: 'BUYER',
      _id: { $ne: req.user.id },
      location: {
        $near: {
          $geometry: {
            type: 'Point',
            coordinates: [numLng, numLat],
          },
          $maxDistance: maxMeters,
        },
      },
    })
      .select('name businessName location address city district state')
      .limit(limitNum)
      .lean();

    const buyerIds = nearbyBuyers.map((b) => b._id);

    const reqFilter = {
      buyerId: { $in: buyerIds },
      status: 'ACTIVE',
      requiredByDate: { $gte: new Date() },
    };
    if (commodity && commodity.trim()) {
      const commFilter = buildCommodityFilter(commodity.trim());
      if (commFilter) Object.assign(reqFilter, commFilter);
    }

    const activeRequirements = await BuyerRequirement.find(reqFilter).lean();

    const reqsByBuyer = {};
    for (const reqItem of activeRequirements) {
      const bId = reqItem.buyerId.toString();
      if (!reqsByBuyer[bId]) reqsByBuyer[bId] = [];
      reqsByBuyer[bId].push({
        id: reqItem._id,
        commodity: reqItem.commodity,
        cropName: reqItem.cropName,
        variety: reqItem.variety,
        grade: reqItem.grade,
        quantity: reqItem.quantity,
        quantityUnit: reqItem.quantityUnit,
        offeredPrice: reqItem.offeredPrice,
        requiredByDate: reqItem.requiredByDate ? reqItem.requiredByDate.toISOString().split('T')[0] : null,
      });
    }

    const results = nearbyBuyers
      .map((buyer) => {
        const [bLng, bLat] = buyer.location.coordinates;
        const distKm = calculateHaversineDistance(numLat, numLng, bLat, bLng);
        const buyerReqs = reqsByBuyer[buyer._id.toString()] || [];

        return {
          buyerId: buyer._id,
          name: buyer.businessName || buyer.name,
          contactName: buyer.name,
          latitude: bLat,
          longitude: bLng,
          address: buyer.address || '',
          district: buyer.district || '',
          state: buyer.state || '',
          distanceKm: distKm,
          requirementCount: buyerReqs.length,
          requirements: buyerReqs,
          googleMapsUrl: buildGoogleMapsUrl(bLat, bLng, `${buyer.businessName || buyer.name} (Buyer)`),
        };
      })
      .filter((b) => !commodity || b.requirementCount > 0);

    results.sort((a, b) => a.distanceKm - b.distanceKm);

    res.status(200).json({
      success: true,
      origin: { latitude: numLat, longitude: numLng },
      maxDistanceKm: maxDist,
      count: results.length,
      data: results,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get nearby APMC / AGMARKNET agricultural markets
 * @route   GET /api/location/nearby-markets
 * @access  Public / Authenticated
 */
const getNearbyMarkets = async (req, res, next) => {
  try {
    let { latitude, longitude, state, district, limit = 20 } = req.query;

    if (!latitude || !longitude) {
      if (req.user?.id) {
        const me = await User.findById(req.user.id).lean();
        if (me?.location?.coordinates?.length === 2) {
          longitude = me.location.coordinates[0];
          latitude = me.location.coordinates[1];
          if (!state && me.state) state = me.state;
          if (!district && me.district) district = me.district;
        }
      }
    }

    const filter = {};
    if (state && state.trim()) {
      filter.state = { $regex: new RegExp(`^${state.trim()}$`, 'i') };
    }
    if (district && district.trim()) {
      filter.district = { $regex: new RegExp(`^${district.trim()}$`, 'i') };
    }

    const limitNum = Math.min(50, Math.max(1, parseInt(limit, 10) || 20));

    // Get distinct markets from dataset with latest price sample
    const markets = await MarketPrice.aggregate([
      { $match: filter },
      { $sort: { date: -1 } },
      {
        $group: {
          _id: { market: '$market', district: '$district', state: '$state' },
          sampleCommodity: { $first: '$commodity' },
          samplePrice: { $first: '$modalPrice' },
          latestDate: { $first: '$date' },
        },
      },
      { $limit: limitNum },
    ]);

    const formatted = markets.map((m) => {
      const marketName = m._id.market;
      const districtName = m._id.district;
      const stateName = m._id.state;

      // Google maps search query for market location
      const queryLabel = `${marketName} Mandi, ${districtName}, ${stateName}`;
      const searchUrl = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(queryLabel)}`;

      return {
        market: marketName,
        district: districtName,
        state: stateName,
        sampleCommodity: m.sampleCommodity,
        samplePrice: m.samplePrice,
        latestDate: m.latestDate ? m.latestDate.toISOString().split('T')[0] : null,
        googleMapsUrl: searchUrl,
      };
    });

    res.status(200).json({
      success: true,
      count: formatted.length,
      data: formatted,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  updateMyLocation,
  getMyLocation,
  getNearbyFarmers,
  getNearbyBuyers,
  getNearbyMarkets,
};
