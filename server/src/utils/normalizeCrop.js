/**
 * Deterministic crop name normalization utility.
 * Cleans whitespace, lowercases, and prepares raw crop input for catalog matching.
 */
const normalizeCropName = (input) => {
  if (!input || typeof input !== 'string') return '';
  return input
    .trim()
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .replace(/[^\w\s-]/gi, '');
};

module.exports = { normalizeCropName };
