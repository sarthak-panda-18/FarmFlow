# AGMARKNET Dataset Data Quality Report

This document details the empirical profiling and data validation performed on the **AGMARKNET India Historical Commodity Prices (2024–2025)** dataset.

---

## 1. Summary Statistics

| Metric | Value |
|---|---|
| **Source File** | `agmarknet_india_historical_prices_2024_2025.csv` |
| **Total CSV Data Rows** | 1,048,575 |
| **Total Columns** | 13 |
| **Valid Records** | 1,047,422 |
| **Invalid Records** | 1,153 |
| **Duplicate Records Skipped** | 0 (after valid filtering) |
| **Earliest Arrival Date** | 2024-08-14 |
| **Latest Arrival Date** | 2025-08-13 |

---

## 2. Categorical Vocabulary Breakdown

- **Unique States**: 8 (`Uttar Pradesh`, `Punjab`, `Haryana`, `Madhya Pradesh`, `Rajasthan`, `Gujarat`, `Maharashtra`, `West Bengal`, etc.)
- **Unique Districts**: 269
- **Unique Wholesale Markets**: 1,371
- **Unique Commodities**: 21
- **Unique Varieties**: 145
- **Unique Quality Grades**: 5 (`FAQ`, `Grade A`, `Medium`, `Large`, `Small`)

---

## 3. Numeric Price Bounds (Valid Records)

- **Minimum Price (`minPrice`)**: ₹0 to ₹300,000 / Quintal
- **Maximum Price (`maxPrice`)**: ₹0 to ₹300,000 / Quintal
- **Modal Price (`modalPrice`)**: ₹20 to ₹250,000 / Quintal

---

## 4. Preprocessing & Validation Rules

1. **Date Parsing**: Date strings formatted as `DD-MMM-YY` (e.g. `05-Apr-25`) are normalized into standard UTC Date objects (`2025-04-05T00:00:00.000Z`).
2. **Numeric Type Conversion**: `minPrice`, `maxPrice`, and `modalPrice` are parsed as numbers.
3. **Price Order Validation**: Records must satisfy `minPrice >= 0`, `maxPrice >= 0`, `modalPrice >= 0`, and `minPrice <= modalPrice <= maxPrice`. Records violating these constraints are rejected.
4. **Required Attributes**: Records missing critical identity attributes (`state`, `market`, `commodity`, `date`) are marked invalid.
5. **Whitespace Normalization**: String fields are trimmed of leading/trailing whitespace.
