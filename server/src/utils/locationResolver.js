/**
 * Robust Location & Address Resolver for FarmFlow
 * Ensures accurate coordinates, complete sanitized address strings,
 * and valid Google Maps URLs without empty queries (e.g. ",").
 */

const { isValidCoordinates, buildGoogleMapsUrl } = require('./geoUtils');
const { getMarketCoordinates } = require('./districtCoordinates');

/**
 * Sanitizes an address string.
 * Strips dangling commas, excessive whitespace, and placeholder phrases.
 * Returns a clean string, or "" if invalid/empty.
 * @param {string|any} raw
 * @returns {string}
 */
function sanitizeAddress(raw) {
  if (!raw || typeof raw !== 'string') {
    return '';
  }

  let cleaned = raw.trim();

  // Strip leading and trailing commas, semicolons, dashes, and whitespace
  cleaned = cleaned.replace(/^[\s,;:\-_/]+|[\s,;:\-_/]+$/g, '').trim();

  // Replace multiple internal commas or comma-spaces like ", ," with single comma
  cleaned = cleaned.replace(/,\s*,+/g, ',').replace(/\s{2,}/g, ' ');

  // If after stripping all punctuation/whitespace nothing is left
  const strippedOfPunctuation = cleaned.replace(/[\s,;:\-_/.]+/g, '');
  if (!strippedOfPunctuation) {
    return '';
  }

  const lower = cleaned.toLowerCase();
  const invalidPlaceholders = [
    'not specified',
    'location not available',
    'address not available',
    'no address',
    'unknown',
    'null',
    'undefined',
    'n/a',
    'none',
  ];

  if (invalidPlaceholders.includes(lower)) {
    return '';
  }

  return cleaned;
}

/**
 * Formats multiple address components into a clean comma-separated string.
 * @param  {...any} parts
 * @returns {string}
 */
function formatAddressParts(...parts) {
  const cleanParts = [];

  for (const part of parts) {
    if (!part) continue;
    if (Array.isArray(part)) {
      for (const sub of part) {
        const s = sanitizeAddress(sub);
        if (s && !cleanParts.includes(s)) cleanParts.push(s);
      }
    } else if (typeof part === 'string') {
      const s = sanitizeAddress(part);
      if (s && !cleanParts.includes(s)) cleanParts.push(s);
    }
  }

  return cleanParts.join(', ');
}

/**
 * Extracts GPS coordinates { lat, lng } from an entity (User, Crop, Requirement, Location object).
 * @param {object} entity
 * @returns {{ lat: number, lng: number } | null}
 */
function extractCoordinates(entity) {
  if (!entity || typeof entity !== 'object') return null;

  // 1. Direct latitude and longitude fields
  if (isValidCoordinates(entity.latitude, entity.longitude)) {
    return { lat: Number(entity.latitude), lng: Number(entity.longitude) };
  }

  // 2. coordinates sub-object { latitude, longitude }
  if (entity.coordinates && typeof entity.coordinates === 'object') {
    if (isValidCoordinates(entity.coordinates.latitude, entity.coordinates.longitude)) {
      return { lat: Number(entity.coordinates.latitude), lng: Number(entity.coordinates.longitude) };
    }
  }

  // 3. GeoJSON Point location { type: 'Point', coordinates: [lng, lat] }
  if (
    entity.location &&
    typeof entity.location === 'object' &&
    Array.isArray(entity.location.coordinates) &&
    entity.location.coordinates.length === 2
  ) {
    const [lng, lat] = entity.location.coordinates;
    if (isValidCoordinates(lat, lng)) {
      return { lat: Number(lat), lng: Number(lng) };
    }
  }

  // 4. locationCoordinates { type: 'Point', coordinates: [lng, lat] }
  if (
    entity.locationCoordinates &&
    typeof entity.locationCoordinates === 'object' &&
    Array.isArray(entity.locationCoordinates.coordinates) &&
    entity.locationCoordinates.length === 2
  ) {
    const [lng, lat] = entity.locationCoordinates.coordinates;
    if (isValidCoordinates(lat, lng)) {
      return { lat: Number(lat), lng: Number(lng) };
    }
  }

  return null;
}

/**
 * Resolves full location data (coordinates, complete sanitized address, and Google Maps URL)
 * for a party (Farmer pickup or Buyer delivery).
 *
 * @param {object} options
 * @param {object} [options.user] - Farmer or Buyer User document
 * @param {object} [options.crop] - Crop listing document (for Farmer)
 * @param {object} [options.requirement] - BuyerRequirement document (for Buyer)
 * @param {object} [options.existingLocation] - Existing location object on Deal ({ address, latitude, longitude })
 * @param {string} [options.partyLabel] - Human-readable label for Google Maps pin
 * @returns {{ address: string, latitude: number|null, longitude: number|null, mapsUrl: string|null, city: string, district: string, state: string }}
 */
function resolvePartyLocation({ user, crop, requirement, existingLocation, partyLabel = '' } = {}) {
  // 1. Extract GPS coordinates
  let coords = null;

  if (existingLocation) {
    coords = extractCoordinates(existingLocation);
  }

  if (!coords && user) {
    coords = extractCoordinates(user);
  }

  if (!coords && crop) {
    coords = extractCoordinates(crop);
  }

  if (!coords && requirement) {
    coords = extractCoordinates(requirement);
  }

  // Extract geographic metadata
  const state = crop?.state || requirement?.state || user?.state || '';
  const district = crop?.district || requirement?.district || user?.district || '';
  const market = crop?.market || requirement?.market || '';
  const city = user?.city || '';

  // If still no GPS coordinates, look up Mandi/District APMC GIS coordinates
  if (!coords && (state || district || market)) {
    const marketCoords = getMarketCoordinates(state, district, market);
    if (marketCoords && isValidCoordinates(marketCoords.lat, marketCoords.lng)) {
      coords = { lat: marketCoords.lat, lng: marketCoords.lng };
    }
  }

  // 2. Resolve complete sanitized address string
  let address = '';

  // Candidate 1: Existing deal address if valid and not empty
  if (existingLocation && existingLocation.address) {
    address = sanitizeAddress(existingLocation.address);
  }

  // Candidate 2: Listing location string (Crop or Requirement)
  if (!address && crop && typeof crop.location === 'string') {
    address = sanitizeAddress(crop.location);
  }
  if (!address && requirement && typeof requirement.location === 'string') {
    address = sanitizeAddress(requirement.location);
  }

  // Candidate 3: Composite from listing market, district, state
  if (!address && (market || district || state)) {
    address = formatAddressParts(market, district, state);
  }

  // Candidate 4: User profile address
  if (!address && user && typeof user.address === 'string') {
    address = sanitizeAddress(user.address);
  }

  // Candidate 5: Composite from user address, city, district, state
  if (!address && user) {
    address = formatAddressParts(user.address, user.city, user.district, user.state);
  }

  // Candidate 6: General fallback composite
  if (!address) {
    address = formatAddressParts(city, district, state);
  }

  // Final check: Address must never be empty commas
  address = sanitizeAddress(address);

  // 3. Build Google Maps URL
  let mapsUrl = null;
  const label = partyLabel || user?.name || (crop ? 'Farmer Pickup' : 'Buyer Delivery');

  if (coords && isValidCoordinates(coords.lat, coords.lng)) {
    mapsUrl = buildGoogleMapsUrl(coords.lat, coords.lng, label);
  } else if (address) {
    mapsUrl = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(address)}`;
  }

  return {
    address,
    latitude: coords ? coords.lat : null,
    longitude: coords ? coords.lng : null,
    mapsUrl,
    city: sanitizeAddress(city),
    district: sanitizeAddress(district),
    state: sanitizeAddress(state),
  };
}

module.exports = {
  sanitizeAddress,
  formatAddressParts,
  extractCoordinates,
  resolvePartyLocation,
};
