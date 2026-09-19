/**
 * Comprehensive District and Mandi Geographic Coordinates Mapping
 * Covers all 8 states in the Farm-to-Market dataset:
 * Andhra Pradesh, Gujarat, Kerala, Madhya Pradesh, Punjab, Rajasthan, Uttar Pradesh, West Bengal.
 */

const STATE_CENTROIDS = {
  'Andhra Pradesh': { lat: 15.9129, lng: 79.7400 },
  'Gujarat': { lat: 22.2587, lng: 71.1924 },
  'Kerala': { lat: 10.8505, lng: 76.2711 },
  'Madhya Pradesh': { lat: 22.9734, lng: 78.6569 },
  'Punjab': { lat: 31.1471, lng: 75.3412 },
  'Rajasthan': { lat: 27.0238, lng: 74.2179 },
  'Uttar Pradesh': { lat: 26.8467, lng: 80.9462 },
  'West Bengal': { lat: 22.9868, lng: 87.8550 },
};

const DISTRICT_COORDINATES = {
  // --- ANDHRA PRADESH ---
  'Andhra Pradesh': {
    'Krishna': { lat: 16.5062, lng: 80.6480 }, // Vijayawada / Machilipatnam
    'Guntur': { lat: 16.3067, lng: 80.4365 },
    'West Godavari': { lat: 16.7107, lng: 81.0952 },
    'East Godavari': { lat: 16.9891, lng: 82.2475 },
    'Visakhapatnam': { lat: 17.6868, lng: 83.2185 },
    'Nellore': { lat: 14.4426, lng: 79.9865 },
    'Kurnool': { lat: 15.8281, lng: 78.0373 },
    'Cuddapah': { lat: 14.4673, lng: 78.8242 },
    'Chittor': { lat: 13.2172, lng: 79.1003 },
    'Anantapur': { lat: 14.6819, lng: 77.6006 },
  },

  // --- GUJARAT ---
  'Gujarat': {
    'Ahmedabad': { lat: 23.0225, lng: 72.5714 },
    'Amreli': { lat: 21.6032, lng: 71.2221 },
    'Anand': { lat: 22.5645, lng: 72.9289 },
    'Banaskanth': { lat: 24.1724, lng: 72.4346 },
    'Bharuch': { lat: 21.7051, lng: 72.9959 },
    'Bhavnagar': { lat: 21.7645, lng: 72.1519 },
    'Botad': { lat: 22.1704, lng: 71.6661 },
    'Chhota Udaipur': { lat: 22.3108, lng: 74.0117 },
    'Dahod': { lat: 22.8376, lng: 74.2546 },
    'Dang': { lat: 20.8354, lng: 73.7146 },
    'Devbhumi Dwarka': { lat: 22.2442, lng: 68.9685 },
    'Gandhinagar': { lat: 23.2156, lng: 72.6369 },
    'Gir Somnath': { lat: 20.9042, lng: 70.3667 },
    'Jamnagar': { lat: 22.4707, lng: 70.0577 },
    'Junagarh': { lat: 21.5222, lng: 70.4579 },
    'Kachchh': { lat: 23.2420, lng: 69.6669 },
    'Kheda': { lat: 22.7516, lng: 72.6845 },
    'Mehsana': { lat: 23.5880, lng: 72.3693 },
    'Morbi': { lat: 22.8173, lng: 70.8377 },
    'Narmada': { lat: 21.8700, lng: 73.5000 },
    'Navsari': { lat: 20.9500, lng: 72.9300 },
    'Panchmahals': { lat: 22.7554, lng: 73.6149 },
    'Patan': { lat: 23.8493, lng: 72.1266 },
    'Porbandar': { lat: 21.6417, lng: 69.6293 },
    'Rajkot': { lat: 22.3039, lng: 70.8022 },
    'Sabarkantha': { lat: 23.5977, lng: 72.9698 },
    'Surat': { lat: 21.1702, lng: 72.8311 },
    'Surendranagar': { lat: 22.7279, lng: 71.6370 },
    'Vadodara(Baroda)': { lat: 22.3072, lng: 73.1812 },
    'Valsad': { lat: 20.5992, lng: 72.9342 },
  },

  // --- KERALA ---
  'Kerala': {
    'Alappuzha': { lat: 9.4981, lng: 76.3388 },
    'Ernakulam': { lat: 9.9816, lng: 76.2999 },
    'Idukki': { lat: 9.9189, lng: 76.9444 },
    'Kannur': { lat: 11.8745, lng: 75.3704 },
    'Kasargod': { lat: 12.4996, lng: 74.9869 },
    'Kollam': { lat: 8.8932, lng: 76.6141 },
    'Kottayam': { lat: 9.5916, lng: 76.5222 },
    'Kozhikode(Calicut)': { lat: 11.2588, lng: 75.7804 },
    'Malappuram': { lat: 11.0510, lng: 76.0711 },
    'Palakad': { lat: 10.7867, lng: 76.6548 },
    'Pathanamthitta': { lat: 9.2648, lng: 76.7870 },
    'Thirssur': { lat: 10.5276, lng: 76.2144 },
    'Thiruvananthapuram': { lat: 8.5241, lng: 76.9366 },
    'Wayanad': { lat: 11.6854, lng: 76.1320 },
  },

  // --- MADHYA PRADESH ---
  'Madhya Pradesh': {
    'Agar Malwa': { lat: 23.7089, lng: 76.0134 },
    'Alirajpur': { lat: 22.3039, lng: 74.3542 },
    'Anupur': { lat: 23.1000, lng: 81.6833 },
    'Ashoknagar': { lat: 24.5767, lng: 77.7281 },
    'Badwani': { lat: 22.0333, lng: 74.9000 },
    'Balaghat': { lat: 21.8000, lng: 80.1833 },
    'Betul': { lat: 21.9000, lng: 77.9000 },
    'Bhind': { lat: 26.5667, lng: 78.7833 },
    'Bhopal': { lat: 23.2599, lng: 77.4126 },
    'Burhanpur': { lat: 21.3167, lng: 76.2333 },
    'Chhatarpur': { lat: 24.9167, lng: 79.5833 },
    'Chhindwara': { lat: 22.0574, lng: 78.9382 },
    'Damoh': { lat: 23.8324, lng: 79.4418 },
    'Datia': { lat: 25.6667, lng: 78.4667 },
    'Dewas': { lat: 22.9676, lng: 76.0534 },
    'Dhar': { lat: 22.5975, lng: 75.2974 },
    'Dindori': { lat: 22.9500, lng: 81.0833 },
    'Guna': { lat: 24.6500, lng: 77.3167 },
    'Gwalior': { lat: 26.2183, lng: 78.1828 },
    'Harda': { lat: 22.3333, lng: 77.1000 },
    'Hoshangabad': { lat: 22.7500, lng: 77.7167 },
    'Indore': { lat: 22.7196, lng: 75.8577 },
    'Jabalpur': { lat: 23.1815, lng: 79.9864 },
    'Jhabua': { lat: 22.7667, lng: 74.6000 },
    'Katni': { lat: 23.8333, lng: 80.4000 },
    'Khandwa': { lat: 21.8333, lng: 76.3500 },
    'Khargone': { lat: 21.8167, lng: 75.6167 },
    'Mandla': { lat: 22.6000, lng: 80.3833 },
    'Mandsaur': { lat: 24.0667, lng: 75.0667 },
    'Morena': { lat: 26.5000, lng: 78.0000 },
    'Narsinghpur': { lat: 22.9500, lng: 79.2000 },
    'Neemuch': { lat: 24.4667, lng: 74.8667 },
    'Panna': { lat: 24.7167, lng: 80.2000 },
    'Raisen': { lat: 23.3333, lng: 77.7833 },
    'Rajgarh': { lat: 24.0167, lng: 76.7333 },
    'Ratlam': { lat: 23.3315, lng: 75.0367 },
    'Rewa': { lat: 24.5362, lng: 81.3037 },
    'Sagar': { lat: 23.8388, lng: 78.7378 },
    'Satna': { lat: 24.6005, lng: 80.8322 },
    'Sehore': { lat: 23.2000, lng: 77.0833 },
    'Seoni': { lat: 22.0833, lng: 79.5500 },
    'Shajapur': { lat: 23.4333, lng: 76.2833 },
    'Shehdol': { lat: 23.2833, lng: 81.3500 },
    'Sheopur': { lat: 25.6667, lng: 76.7000 },
    'Shivpuri': { lat: 25.4333, lng: 77.6500 },
    'Sidhi': { lat: 24.4167, lng: 81.8833 },
    'Singroli': { lat: 24.2000, lng: 82.6667 },
    'Tikamgarh': { lat: 24.7500, lng: 78.8333 },
    'Ujjain': { lat: 23.1765, lng: 75.7885 },
    'Umariya': { lat: 23.5333, lng: 80.8333 },
    'Vidisha': { lat: 23.5333, lng: 77.8167 },
  },

  // --- PUNJAB ---
  'Punjab': {
    'Amritsar': { lat: 31.6340, lng: 74.8723 },
    'Barnala': { lat: 30.3833, lng: 75.5500 },
    'Bhatinda': { lat: 30.2110, lng: 74.9455 },
    'Faridkot': { lat: 30.6667, lng: 74.7500 },
    'Fatehgarh': { lat: 30.6500, lng: 76.4000 },
    'Fazilka': { lat: 30.4036, lng: 74.0254 },
    'Ferozpur': { lat: 30.9237, lng: 74.6065 },
    'Gurdaspur': { lat: 32.0419, lng: 75.4053 },
    'Hoshiarpur': { lat: 31.5273, lng: 75.9149 },
    'Jalandhar': { lat: 31.3260, lng: 75.5762 },
    'Ludhiana': { lat: 30.9010, lng: 75.8573 },
    'Mansa': { lat: 29.9833, lng: 75.3833 },
    'Moga': { lat: 30.8167, lng: 75.1667 },
    'Mohali': { lat: 30.7046, lng: 76.7179 },
    'Muktsar': { lat: 30.4833, lng: 74.5167 },
    'Nawanshahr': { lat: 31.1333, lng: 76.1167 },
    'Pathankot': { lat: 32.2684, lng: 75.6499 },
    'Patiala': { lat: 30.3398, lng: 76.3869 },
    'Ropar (Rupnagar)': { lat: 30.9667, lng: 76.5333 },
    'Sangrur': { lat: 30.2500, lng: 75.8333 },
    'Tarntaran': { lat: 31.4500, lng: 74.9333 },
    'kapurthala': { lat: 31.3800, lng: 75.3800 },
  },

  // --- RAJASTHAN ---
  'Rajasthan': {
    'Ajmer': { lat: 26.4499, lng: 74.6399 },
    'Alwar': { lat: 27.5530, lng: 76.6346 },
    'Anupgarh': { lat: 29.1911, lng: 73.2086 },
    'Balotra': { lat: 25.8333, lng: 72.2333 },
    'Baran': { lat: 25.1000, lng: 76.5167 },
    'Barmer': { lat: 25.7500, lng: 71.3833 },
    'Beawar': { lat: 26.1000, lng: 74.3167 },
    'Bharatpur': { lat: 27.2173, lng: 77.4895 },
    'Bhilwara': { lat: 25.3500, lng: 74.6333 },
    'Bikaner': { lat: 28.0229, lng: 73.3119 },
    'Bundi': { lat: 25.4400, lng: 75.6400 },
    'Chittorgarh': { lat: 24.8887, lng: 74.6269 },
    'Churu': { lat: 28.3000, lng: 74.9667 },
    'Dausa': { lat: 26.8833, lng: 76.3333 },
    'Deedwana Kuchaman': { lat: 27.1400, lng: 74.5800 },
    'Deeg': { lat: 27.4700, lng: 77.3200 },
    'Dholpur': { lat: 26.7000, lng: 77.9000 },
    'Dudu': { lat: 26.6800, lng: 75.2400 },
    'Dungarpur': { lat: 23.8400, lng: 73.7200 },
    'Ganganagar': { lat: 29.9167, lng: 73.8833 },
    'Gangapur City': { lat: 26.4700, lng: 76.7200 },
    'Hanumangarh': { lat: 29.5800, lng: 74.3200 },
    'Jaipur': { lat: 26.9124, lng: 75.7873 },
    'Jaipur Rural': { lat: 26.9500, lng: 75.8000 },
    'Jaisalmer': { lat: 26.9157, lng: 70.9083 },
    'Jalore': { lat: 25.3500, lng: 72.6167 },
    'Jhalawar': { lat: 24.6000, lng: 76.1667 },
    'Jhunjhunu': { lat: 28.1300, lng: 75.4000 },
    'Jodhpur': { lat: 26.2389, lng: 73.0243 },
    'Jodhpur Rural': { lat: 26.3000, lng: 73.0500 },
    'Karauli': { lat: 26.5000, lng: 77.0200 },
    'Kekri': { lat: 25.9700, lng: 75.1500 },
    'Khairthal Tijara': { lat: 27.9300, lng: 76.8300 },
    'Kota': { lat: 25.2138, lng: 75.8648 },
    'Kotputli- Behror': { lat: 27.7000, lng: 76.2000 },
    'Nagaur': { lat: 27.2000, lng: 73.7400 },
    'Neem Ka Thana': { lat: 27.7400, lng: 75.7800 },
    'Pali': { lat: 25.7700, lng: 73.3300 },
    'Phalodi': { lat: 27.1300, lng: 72.3600 },
    'Pratapgarh': { lat: 24.0300, lng: 74.7800 },
    'Rajsamand': { lat: 25.0700, lng: 73.8800 },
    'Sanchore': { lat: 24.7500, lng: 71.7700 },
    'Sikar': { lat: 27.6100, lng: 75.1400 },
    'Sirohi': { lat: 24.8800, lng: 72.8600 },
    'Swai Madhopur': { lat: 26.0000, lng: 76.3500 },
    'Tonk': { lat: 26.1700, lng: 75.7800 },
    'Udaipur': { lat: 24.5854, lng: 73.7125 },
  },

  // --- UTTAR PRADESH ---
  'Uttar Pradesh': {
    'Agra': { lat: 27.1767, lng: 78.0081 },
    'Aligarh': { lat: 27.8974, lng: 78.0880 },
    'Ambedkarnagar': { lat: 26.4500, lng: 82.6800 },
    'Amethi': { lat: 26.1500, lng: 81.8200 },
    'Amroha': { lat: 28.9000, lng: 78.4700 },
    'Auraiya': { lat: 26.4700, lng: 79.5200 },
    'Ayodhya': { lat: 26.7922, lng: 82.1998 },
    'Azamgarh': { lat: 26.0688, lng: 83.1859 },
    'Badaun': { lat: 28.0300, lng: 79.1200 },
    'Baghpat': { lat: 28.9500, lng: 77.2200 },
    'Bahraich': { lat: 27.5800, lng: 81.6000 },
    'Ballia': { lat: 25.7600, lng: 84.1500 },
    'Balrampur': { lat: 27.4300, lng: 82.1800 },
    'Banda': { lat: 25.4800, lng: 80.3300 },
    'Barabanki': { lat: 26.9200, lng: 81.1800 },
    'Bareilly': { lat: 28.3670, lng: 79.4304 },
    'Basti': { lat: 26.8000, lng: 82.7200 },
    'Bhadohi(Sant Ravi Nagar)': { lat: 25.4200, lng: 82.5700 },
    'Bijnor': { lat: 29.3700, lng: 78.1300 },
    'Bulandshahar': { lat: 28.4000, lng: 77.8500 },
    'Chandauli': { lat: 25.2700, lng: 83.2700 },
    'Chitrakut': { lat: 25.2000, lng: 80.9000 },
    'Deoria': { lat: 26.5000, lng: 83.7800 },
    'Etah': { lat: 27.6300, lng: 78.6700 },
    'Etawah': { lat: 26.7700, lng: 79.0300 },
    'Farukhabad': { lat: 27.3800, lng: 79.5800 },
    'Fatehpur': { lat: 25.9300, lng: 80.8000 },
    'Firozabad': { lat: 27.1500, lng: 78.4000 },
    'Gautam Budh Nagar': { lat: 28.5355, lng: 77.3910 },
    'Ghaziabad': { lat: 28.6692, lng: 77.4538 },
    'Ghazipur': { lat: 25.5800, lng: 83.5800 },
    'Gonda': { lat: 27.1300, lng: 81.9700 },
    'Gorakhpur': { lat: 26.7606, lng: 83.3732 },
    'Hamirpur': { lat: 25.9500, lng: 80.1500 },
    'Hardoi': { lat: 27.4200, lng: 80.1200 },
    'Hathras': { lat: 27.6000, lng: 78.0500 },
    'Jalaun (Orai)': { lat: 25.9900, lng: 79.4500 },
    'Jaunpur': { lat: 25.7500, lng: 82.6800 },
    'Jhansi': { lat: 25.4484, lng: 78.5685 },
    'Kannuj': { lat: 27.0500, lng: 79.9200 },
    'Kanpur': { lat: 26.4499, lng: 80.3319 },
    'Kanpur Dehat': { lat: 26.3300, lng: 79.9500 },
    'Kasganj': { lat: 27.8100, lng: 78.6500 },
    'Kaushambi': { lat: 25.5300, lng: 81.4000 },
    'Khiri (Lakhimpur)': { lat: 27.9500, lng: 80.7700 },
    'Kushinagar': { lat: 26.9000, lng: 83.9500 },
    'Lakhimpur': { lat: 27.9500, lng: 80.7700 },
    'Lalitpur': { lat: 24.6900, lng: 78.4100 },
    'Lucknow': { lat: 26.8467, lng: 80.9462 },
    'Maharajganj': { lat: 27.1500, lng: 83.5700 },
    'Mahoba': { lat: 25.2800, lng: 79.8700 },
    'Mainpuri': { lat: 27.2300, lng: 79.0300 },
    'Mathura': { lat: 27.4924, lng: 77.6737 },
    'Mau(Maunathbhanjan)': { lat: 25.9500, lng: 83.5500 },
    'Meerut': { lat: 28.9845, lng: 77.7064 },
    'Mirzapur': { lat: 25.1500, lng: 82.5800 },
    'Muzaffarnagar': { lat: 29.4700, lng: 77.7000 },
    'Pillibhit': { lat: 28.6300, lng: 79.8000 },
    'Pratapgarh': { lat: 25.9000, lng: 81.9500 },
    'Prayagraj': { lat: 25.4358, lng: 81.8463 },
    'Raebarelli': { lat: 26.2300, lng: 81.2400 },
    'Rampur': { lat: 28.8000, lng: 79.0200 },
    'Saharanpur': { lat: 29.9640, lng: 77.5460 },
    'Sambhal': { lat: 28.5800, lng: 78.5700 },
    'Sant Kabir Nagar': { lat: 26.7800, lng: 83.0300 },
    'Shahjahanpur': { lat: 27.8800, lng: 79.9100 },
    'Shamli': { lat: 29.4500, lng: 77.3000 },
    'Shravasti': { lat: 27.7000, lng: 81.9000 },
    'Siddharth Nagar': { lat: 27.3000, lng: 82.8000 },
    'Sitapur': { lat: 27.5700, lng: 80.6800 },
    'Sonbhadra': { lat: 24.6800, lng: 83.0700 },
    'Unnao': { lat: 26.5500, lng: 80.4900 },
    'Varanasi': { lat: 25.3176, lng: 82.9739 },
  },

  // --- WEST BENGAL ---
  'West Bengal': {
    'Alipurduar': { lat: 26.4919, lng: 89.5271 },
    'Bankura': { lat: 23.2324, lng: 87.0715 },
    'Birbhum': { lat: 23.8438, lng: 87.6186 },
    'Coochbehar': { lat: 26.3239, lng: 89.4510 },
    'Dakshin Dinajpur': { lat: 25.2200, lng: 88.7600 },
    'Darjeeling': { lat: 27.0410, lng: 88.2663 },
    'Hooghly': { lat: 22.9030, lng: 88.3968 },
    'Howrah': { lat: 22.5958, lng: 88.2636 },
    'Jalpaiguri': { lat: 26.5404, lng: 88.7196 },
    'Jhargram': { lat: 22.4500, lng: 86.9800 },
    'Kalimpong': { lat: 27.0600, lng: 88.4700 },
    'Kolkata': { lat: 22.5726, lng: 88.3639 },
    'Malda': { lat: 25.0000, lng: 88.1400 },
    'Medinipur(E)': { lat: 22.3000, lng: 87.9200 },
    'Medinipur(W)': { lat: 22.4257, lng: 87.3199 },
    'Murshidabad': { lat: 24.1800, lng: 88.2700 },
    'Nadia': { lat: 23.4710, lng: 88.5565 },
    'North 24 Parganas': { lat: 22.7200, lng: 88.4800 },
    'Paschim Bardhaman': { lat: 23.6889, lng: 86.9661 },
    'Purba Bardhaman': { lat: 23.2324, lng: 87.8615 },
    'Puruliya': { lat: 23.3300, lng: 86.3600 },
    'Sounth 24 Parganas': { lat: 22.1500, lng: 88.4500 },
    'Uttar Dinajpur': { lat: 25.6200, lng: 88.1200 },
  },
};

// Specific APMC Mandi coordinates (for high precision within districts)
const SPECIFIC_MARKET_COORDINATES = {
  // Andhra Pradesh Mandis
  'Kanchekacherla': { lat: 16.6394, lng: 80.3957 },
  'Mylavaram': { lat: 16.7628, lng: 80.6394 },
  'Jaggayyapeta': { lat: 16.8928, lng: 80.0975 },
  'Tiruvuru': { lat: 17.1122, lng: 80.6128 },
  'Tadikonda': { lat: 16.4253, lng: 80.4475 },
  'Chintalapudi': { lat: 17.0667, lng: 80.9833 },
  'Rajahmundry': { lat: 17.0005, lng: 81.8040 },
  'Dharmavaram': { lat: 14.4142, lng: 77.7214 },
  'Kadiri': { lat: 14.1167, lng: 78.1667 },
  'Tenakallu': { lat: 13.9167, lng: 78.3333 },
  'Bangarupalem': { lat: 13.1833, lng: 78.9667 },
  'Chittoor': { lat: 13.2172, lng: 79.1003 },
  'Palamaner': { lat: 13.2000, lng: 78.7500 },
  'Piler': { lat: 13.6833, lng: 78.9333 },
  'Puttur': { lat: 13.4333, lng: 79.5500 },
  'Tirupati': { lat: 13.6288, lng: 79.4192 },
  'Vepanjari': { lat: 13.3333, lng: 79.1667 },
  'Cuddapah': { lat: 14.4673, lng: 78.8242 },
  'Jammalamadugu': { lat: 14.8333, lng: 78.3833 },
  'Lakkireddipally': { lat: 14.1667, lng: 78.7000 },
  'Pulivendala': { lat: 14.4230, lng: 78.2323 },
  'Adoni': { lat: 15.6322, lng: 77.2728 },
  'Kurnool': { lat: 15.8281, lng: 78.0373 },
  'Nandyal': { lat: 15.4882, lng: 78.4836 },
  'Yemmiganur': { lat: 15.7667, lng: 77.4833 },
  'Atmakur(SPS)': { lat: 14.6167, lng: 79.6167 },
  'Gudur': { lat: 14.1463, lng: 79.8504 },
  'Rapur': { lat: 14.2000, lng: 79.5333 },
  'Venkatagiri': { lat: 13.9667, lng: 79.5833 },
  'Anakapally': { lat: 17.6913, lng: 83.0039 },

  // Madhya Pradesh / UP / Rajasthan Mandis
  'Paatan': { lat: 23.2833, lng: 79.7000 },
  'Tamkuhi road': { lat: 26.8500, lng: 84.1800 },
  'Nagaur': { lat: 27.2000, lng: 73.7400 },
  'Jayal': { lat: 27.2200, lng: 74.1900 },
};

/**
 * Returns geographic coordinates for a market, district, and state.
 * Resolution priority:
 * 1. Specific Mandi lookup
 * 2. District coordinate
 * 3. State centroid fallback
 * @param {string} state
 * @param {string} district
 * @param {string} market
 * @returns {{lat: number, lng: number}}
 */
function getMarketCoordinates(state, district, market) {
  if (market && SPECIFIC_MARKET_COORDINATES[market]) {
    return SPECIFIC_MARKET_COORDINATES[market];
  }

  if (state && district && DISTRICT_COORDINATES[state] && DISTRICT_COORDINATES[state][district]) {
    return DISTRICT_COORDINATES[state][district];
  }

  // Case-insensitive district match within state
  if (state && district && DISTRICT_COORDINATES[state]) {
    const distMap = DISTRICT_COORDINATES[state];
    const matchKey = Object.keys(distMap).find(
      (k) => k.toLowerCase() === district.trim().toLowerCase()
    );
    if (matchKey) {
      return distMap[matchKey];
    }
  }

  // State Centroid fallback
  if (state && STATE_CENTROIDS[state]) {
    return STATE_CENTROIDS[state];
  }

  // General India Centroid
  return { lat: 20.5937, lng: 78.9629 };
}

module.exports = {
  STATE_CENTROIDS,
  DISTRICT_COORDINATES,
  SPECIFIC_MARKET_COORDINATES,
  getMarketCoordinates,
};
