/**
 * Commodity Category and Alias Mapping Utility
 * Maps search terms, category names, and aliases to exact AGMARKNET dataset commodity names.
 */

const CATEGORY_MAP = {
  pulses: ['Green Gram (Moong)(Whole)'],
  pulse: ['Green Gram (Moong)(Whole)'],
  dal: ['Green Gram (Moong)(Whole)'],
  dhal: ['Green Gram (Moong)(Whole)'],
  legumes: ['Green Gram (Moong)(Whole)'],

  vegetables: [
    'Bhindi(Ladies Finger)',
    'Brinjal',
    'Cabbage',
    'Carrot',
    'Cauliflower',
    'Garlic',
    'Ginger(Green)',
    'Green Chilli',
  ],
  vegetable: [
    'Bhindi(Ladies Finger)',
    'Brinjal',
    'Cabbage',
    'Carrot',
    'Cauliflower',
    'Garlic',
    'Ginger(Green)',
    'Green Chilli',
  ],
  veg: [
    'Bhindi(Ladies Finger)',
    'Brinjal',
    'Cabbage',
    'Carrot',
    'Cauliflower',
    'Garlic',
    'Ginger(Green)',
    'Green Chilli',
  ],

  cereals: ['Wheat', 'Maize', 'Jowar(Sorghum)', 'Bajra(Pearl Millet/Cumbu)'],
  cereal: ['Wheat', 'Maize', 'Jowar(Sorghum)', 'Bajra(Pearl Millet/Cumbu)'],
  grains: ['Wheat', 'Maize', 'Jowar(Sorghum)', 'Bajra(Pearl Millet/Cumbu)'],

  fruits: ['Apple', 'Banana', 'Mango'],
  fruit: ['Apple', 'Banana', 'Mango'],

  oilseeds: ['Groundnut', 'Mustard', 'Soyabean'],
  oilseed: ['Groundnut', 'Mustard', 'Soyabean'],

  commercial: ['Cotton', 'Gur(Jaggery)'],
};

const ALIAS_MAP = {
  // Pulses
  moong: 'Green Gram (Moong)(Whole)',
  'green gram': 'Green Gram (Moong)(Whole)',
  'moong dal': 'Green Gram (Moong)(Whole)',
  mung: 'Green Gram (Moong)(Whole)',
  'green gram (moong)': 'Green Gram (Moong)(Whole)',
  'green gram (moong)(whole)': 'Green Gram (Moong)(Whole)',

  // Vegetables
  bhindi: 'Bhindi(Ladies Finger)',
  'ladies finger': 'Bhindi(Ladies Finger)',
  ladyfinger: 'Bhindi(Ladies Finger)',
  'lady finger': 'Bhindi(Ladies Finger)',
  okra: 'Bhindi(Ladies Finger)',
  'bhindi(ladies finger)': 'Bhindi(Ladies Finger)',

  brinjal: 'Brinjal',
  eggplant: 'Brinjal',
  baingan: 'Brinjal',
  aubergine: 'Brinjal',

  cabbage: 'Cabbage',
  'patta gobhi': 'Cabbage',
  bandgobhi: 'Cabbage',

  carrot: 'Carrot',
  gajar: 'Carrot',

  cauliflower: 'Cauliflower',
  'phool gobhi': 'Cauliflower',
  gobhi: 'Cauliflower',

  garlic: 'Garlic',
  lahsun: 'Garlic',
  lasun: 'Garlic',

  ginger: 'Ginger(Green)',
  'green ginger': 'Ginger(Green)',
  'ginger(green)': 'Ginger(Green)',
  adrak: 'Ginger(Green)',

  chilli: 'Green Chilli',
  chili: 'Green Chilli',
  'green chilli': 'Green Chilli',
  'green chili': 'Green Chilli',
  mirchi: 'Green Chilli',
  'hari mirch': 'Green Chilli',

  // Cereals
  wheat: 'Wheat',
  gehu: 'Wheat',
  maize: 'Maize',
  corn: 'Maize',
  makka: 'Maize',
  jowar: 'Jowar(Sorghum)',
  'jowar(sorghum)': 'Jowar(Sorghum)',
  sorghum: 'Jowar(Sorghum)',
  bajra: 'Bajra(Pearl Millet/Cumbu)',
  'bajra(pearl millet/cumbu)': 'Bajra(Pearl Millet/Cumbu)',
  millet: 'Bajra(Pearl Millet/Cumbu)',
  cumbu: 'Bajra(Pearl Millet/Cumbu)',

  // Fruits
  apple: 'Apple',
  seb: 'Apple',
  banana: 'Banana',
  kela: 'Banana',
  mango: 'Mango',
  aam: 'Mango',

  // Oilseeds
  groundnut: 'Groundnut',
  peanut: 'Groundnut',
  moongfali: 'Groundnut',
  mungfali: 'Groundnut',
  mustard: 'Mustard',
  sarson: 'Mustard',
  rai: 'Mustard',
  soyabean: 'Soyabean',
  soybean: 'Soyabean',

  // Commercial
  cotton: 'Cotton',
  kapas: 'Cotton',
  jaggery: 'Gur(Jaggery)',
  gur: 'Gur(Jaggery)',
  'gur(jaggery)': 'Gur(Jaggery)',
};

/**
 * Builds MongoDB query condition for commodity search / filtering
 */
const buildCommodityFilter = (commodityQuery) => {
  if (!commodityQuery || typeof commodityQuery !== 'string' || !commodityQuery.trim()) {
    return null;
  }

  const queryLower = commodityQuery.trim().toLowerCase();

  // 1. Check if category search
  if (CATEGORY_MAP[queryLower]) {
    const matchedComms = CATEGORY_MAP[queryLower];
    return { commodity: { $in: matchedComms } };
  }

  // 2. Check alias map
  if (ALIAS_MAP[queryLower]) {
    const exactName = ALIAS_MAP[queryLower];
    return { commodity: exactName };
  }

  // 3. Fallback: sanitized regex match
  const escaped = queryLower.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&');
  return { commodity: new RegExp(escaped, 'i') };
};

module.exports = {
  CATEGORY_MAP,
  ALIAS_MAP,
  buildCommodityFilter,
};
