const Rating = require('../models/Rating');

/**
 * Calculates rating statistics for a given target user (Farmer or Buyer)
 */
const getUserRatingStats = async (userId, userRole = 'FARMER') => {
  if (!userId) {
    return {
      rating: null,
      ratingCount: 0,
      isNew: true,
      displayRating: userRole === 'FARMER' ? 'New Farmer' : 'New Buyer',
      label: 'No ratings yet',
    };
  }

  const ratings = await Rating.find({ toUserId: userId });

  if (!ratings || ratings.length === 0) {
    return {
      rating: null,
      ratingCount: 0,
      isNew: true,
      displayRating: userRole === 'FARMER' ? 'New Farmer' : 'New Buyer',
      label: 'No ratings yet',
    };
  }

  const totalSum = ratings.reduce((sum, r) => sum + r.rating, 0);
  const average = totalSum / ratings.length;
  const formattedAvg = parseFloat(average.toFixed(1));

  return {
    rating: formattedAvg,
    ratingCount: ratings.length,
    isNew: false,
    displayRating: `${formattedAvg} ⭐`,
    label: `${formattedAvg} (${ratings.length} ${ratings.length === 1 ? 'rating' : 'ratings'})`,
  };
};

module.exports = { getUserRatingStats };
