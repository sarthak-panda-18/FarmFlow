/**
 * Geospatial Utilities for Farm-to-Market
 * Handles Haversine distance, coordinate validation, GeoJSON construction, and Google Maps URL generation.
 */

const EARTH_RADIUS_KM = 6371.0;

/**
 * Calculates great-circle distance between two GPS coordinates using Haversine formula
 * @param {number} lat1 Latitude of point 1
 * @param {number} lon1 Longitude of point 1
 * @param {number} lat2 Latitude of point 2
 * @param {number} lon2 Longitude of point 2
 * @returns {number|null} Distance in kilometers rounded to 1 decimal place, or null if coordinates invalid
 */
const calculateHaversineDistance = (lat1, lon1, lat2, lon2) => {
  if (
    lat1 === undefined ||
    lat1 === null ||
    lon1 === undefined ||
    lon1 === null ||
    lat2 === undefined ||
    lat2 === null ||
    lon2 === undefined ||
    lon2 === null
  ) {
    return null;
  }

  const numLat1 = Number(lat1);
  const numLon1 = Number(lon1);
  const numLat2 = Number(lat2);
  const numLon2 = Number(lon2);

  if (isNaN(numLat1) || isNaN(numLon1) || isNaN(numLat2) || isNaN(numLon2)) {
    return null;
  }

  const dLat = ((numLat2 - numLat1) * Math.PI) / 180.0;
  const dLon = ((numLon2 - numLon1) * Math.PI) / 180.0;

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((numLat1 * Math.PI) / 180.0) *
      Math.cos((numLat2 * Math.PI) / 180.0) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const distance = EARTH_RADIUS_KM * c;

  return Math.round(distance * 10) / 10;
};

/**
 * Validates latitude and longitude values
 * @param {number} lat
 * @param {number} lng
 * @returns {boolean}
 */
const isValidCoordinates = (lat, lng) => {
  if (lat === undefined || lat === null || lng === undefined || lng === null) {
    return false;
  }
  const nLat = Number(lat);
  const nLng = Number(lng);
  return (
    !isNaN(nLat) &&
    !isNaN(nLng) &&
    nLat >= -90 &&
    nLat <= 90 &&
    nLng >= -180 &&
    nLng <= 180
  );
};

/**
 * Constructs standard GeoJSON Point object: [longitude, latitude]
 * @param {number} longitude
 * @param {number} latitude
 * @returns {object|null}
 */
const buildGeoJsonPoint = (longitude, latitude) => {
  if (!isValidCoordinates(latitude, longitude)) {
    return null;
  }
  return {
    type: 'Point',
    coordinates: [Number(longitude), Number(latitude)],
  };
};

/**
 * Builds Google Maps search / navigation URL
 * @param {number} latitude
 * @param {number} longitude
 * @param {string} [label]
 * @returns {string}
 */
const buildGoogleMapsUrl = (latitude, longitude, label = '') => {
  if (!isValidCoordinates(latitude, longitude)) {
    return '';
  }
  const base = 'https://www.google.com/maps/search/?api=1&query=';
  return `${base}${encodeURIComponent(`${latitude},${longitude}`)}`;
};

module.exports = {
  calculateHaversineDistance,
  isValidCoordinates,
  buildGeoJsonPoint,
  buildGoogleMapsUrl,
  EARTH_RADIUS_KM,
};
