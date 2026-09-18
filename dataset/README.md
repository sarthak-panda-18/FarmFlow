# Kaggle AGMARKNET Commodity Prices Dataset

This folder contains the market-price reference dataset for the **Intelligent Farm-to-Market Decision & Buyer Recommendation Platform**.

## Dataset Reference
**Filename**: `agmarknet_india_historical_prices_2024_2025.csv`
**Source**: Kaggle — AGMARKNET India Commodity Prices (Aug 2024 – Aug 2025)
**Total Records**: 1,048,575 rows

## CSV Field Mapping to MongoDB Schema

| CSV Column | MongoDB Field | Type | Description |
|---|---|---|---|
| `State` | `state` | String | State name (e.g., Uttar Pradesh) |
| `District Name` | `district` | String | District name |
| `Market Name` | `market` | String | Wholesale market name |
| `Commodity` | `commodity` | String | Commodity name (e.g., Wheat, Tomato) |
| `Variety` | `variety` | String | Crop variety (e.g., Dara, Local) |
| `Grade` | `grade` | String | Quality grade (e.g., FAQ, Grade A) |
| `Min Price (Rs./Quintal)` | `minPrice` | Number | Minimum recorded price per quintal |
| `Max Price (Rs./Quintal)` | `maxPrice` | Number | Maximum recorded price per quintal |
| `Modal Price (Rs./Quintal)` | `modalPrice` | Number | Modal (most common) price per quintal |
| `Price Date` | `date` | Date | Price record date |

## Purpose & Data Usage
- **Commodity Vocabulary**: Provides standard names for 21 agricultural commodities.
- **Market Reference Prices**: Empirically derived min, max, and modal prices across 1,371 wholesale markets.
- **Decision Support**: Enables price trend analysis, location-based comparison, and farmer net return calculations.

See [DATA_QUALITY.md](./DATA_QUALITY.md) for full profiling statistics and quality validation details.
