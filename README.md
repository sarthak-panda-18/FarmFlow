# Intelligent Farm-to-Market Decision & Buyer Recommendation Platform

A data-driven mobile decision-support platform designed to empower farmers by recommending optimal selling locations, timing, quantity allocations, and buyer matchings to maximize net farm returns.

---

## 1. Problem Statement
Smallholder farmers frequently suffer from price information asymmetry, high transportation costs, and post-harvest spoilage risks. Without real-time market insight and access to direct buyer requirements, farmers are often forced to sell locally at distress prices or bear unviable logistics costs to distant wholesale markets.

## 2. Solution Overview
The **Intelligent Farm-to-Market Decision & Buyer Recommendation Platform** bridges the gap between farmers, wholesale markets (AGMARKNET data), and direct buyers. By synthesizing historical price trends, transportation expenses, shelf-life risk factors, quality matching, and registered buyer requirements, the platform provides tailored, actionable recommendations on **where, when, and how much** to sell.

> **IMPORTANT**: This application is strictly a **decision-support and buyer-discovery platform**. It does **NOT** process financial transactions, manage payment gateways, or settle financial trades.

## 3. Core Features (Target Platform Capabilities)
* **Market Price & Trend Analysis**: Historical AGMARKNET price benchmarks across state and district markets.
* **Smart Buyer Matching**: Compatible buyer discovery based on crop variety, quality grade, required quantity, and price.
* **Logistics & Net Return Optimization**: Net return calculations taking into account distance, transport cost, and spoilage risk.
* **Partial Quantity Allocation**: Splitting crop batches across multiple buyers or markets to optimize revenue.
* **Farmer & Buyer Dashboards**: Role-tailored mobile experience for listing crops, registering buyer demand, and reviewing recommendations.

## 4. Architecture
The platform is built on a modern decoupled full-stack mobile architecture:
```
┌──────────────────────────────────────────────┐
│           Flutter Mobile App (Client)        │
│   (Material 3, Provider, Dio, GoRouter)       │
└──────────────────────┬───────────────────────┘
                       │ HTTP / REST API (JSON)
┌──────────────────────▼───────────────────────┐
│           Node.js + Express Server           │
│     (Auth Middleware, JWT, Controllers)      │
└──────────────────────┬───────────────────────┘
                       │ Mongoose Driver
┌──────────────────────▼───────────────────────┐
│            MongoDB Database                  │
│    (Users, Crops, Requirements, Prices)      │
└──────────────────────────────────────────────┘
```

## 5. Technology Stack
* **Mobile Application**: Flutter, Dart, Material 3, Provider, Dio, GoRouter, flutter_secure_storage.
* **Backend Application**: Node.js, Express.js (JavaScript, async/await).
* **Database**: MongoDB, Mongoose ODM.
* **Security & Tools**: JWT, bcryptjs, Helmet, CORS, Morgan, dotenv.

## 6. Folder Structure
```
farm-to-market/
│
├── mobile/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── config/
│   │   │   └── app_config.dart
│   │   ├── constants/
│   │   │   ├── app_colors.dart
│   │   │   ├── app_strings.dart
│   │   │   └── app_constants.dart
│   │   ├── models/
│   │   ├── navigation/
│   │   │   └── app_router.dart
│   │   ├── providers/
│   │   │   ├── auth_provider.dart
│   │   │   ├── farmer_provider.dart
│   │   │   └── buyer_provider.dart
│   │   ├── screens/
│   │   │   ├── auth/
│   │   │   │   ├── login_screen.dart
│   │   │   │   └── register_screen.dart
│   │   │   ├── farmer/
│   │   │   │   ├── farmer_dashboard_screen.dart
│   │   │   │   ├── my_crops_screen.dart
│   │   │   │   └── farmer_recommendations_screen.dart
│   │   │   └── buyer/
│   │   │       ├── buyer_dashboard_screen.dart
│   │   │       ├── buyer_requirements_screen.dart
│   │   │       └── buyer_profile_screen.dart
│   │   ├── services/
│   │   │   ├── api_service.dart
│   │   │   └── storage_service.dart
│   │   ├── utils/
│   │   └── widgets/
│   ├── assets/
│   │   ├── images/
│   │   └── icons/
│   ├── pubspec.yaml
│   └── .env.example
│
├── server/
│   ├── src/
│   │   ├── config/
│   │   │   └── database.js
│   │   ├── controllers/
│   │   ├── middleware/
│   │   │   ├── authMiddleware.js
│   │   │   ├── roleMiddleware.js
│   │   │   └── errorMiddleware.js
│   │   ├── models/
│   │   │   ├── User.js
│   │   │   ├── FarmerCrop.js
│   │   │   ├── BuyerRequirement.js
│   │   │   ├── MarketPrice.js
│   │   │   ├── BuyerFeedback.js
│   │   │   └── Notification.js
│   │   ├── routes/
│   │   │   ├── authRoutes.js
│   │   │   ├── farmerRoutes.js
│   │   │   ├── buyerRoutes.js
│   │   │   ├── marketRoutes.js
│   │   │   ├── recommendationRoutes.js
│   │   │   ├── commodityRoutes.js
│   │   │   ├── allocationRoutes.js
│   │   │   └── notificationRoutes.js
│   │   ├── services/
│   │   ├── utils/
│   │   │   ├── jwt.js
│   │   │   └── password.js
│   │   └── app.js
│   ├── server.js
│   ├── package.json
│   └── .env.example
│
├── dataset/
│   └── README.md
│
├── .gitignore
└── README.md
```

## 7. Flutter Setup
1. Navigate to the mobile directory:
   ```bash
   cd mobile
   ```
2. Copy environment file:
   ```bash
   cp .env.example .env
   ```
3. Fetch dependencies:
   ```bash
   flutter pub get
   ```
4. Run application:
   ```bash
   flutter run
   ```

## 8. Backend Setup
1. Navigate to the server directory:
   ```bash
   cd server
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Copy environment file:
   ```bash
   cp .env.example .env
   ```
4. Start the server:
   ```bash
   npm start
   # or for development:
   npm run dev
   ```

## 9. MongoDB Setup
Ensure MongoDB is running locally on port `27017` or update `MONGODB_URI` in `server/.env` to point to a MongoDB Atlas cluster URI.
```bash
# Example local MongoDB URI
MONGODB_URI=mongodb://localhost:27017/farm-to-market
```

## 10. Environment Variables
### Backend (`server/.env.example`)
* `PORT`: Server listening port (default `5000`).
* `MONGODB_URI`: MongoDB connection string.
* `JWT_SECRET`: Secret key for JWT signing.
* `NODE_ENV`: Application environment (`development` / `production`).

### Mobile (`mobile/.env.example`)
* `API_BASE_URL`: Base URL for Express REST API endpoints (e.g. `http://localhost:5000/api` or `http://10.0.2.2:5000/api` for Android Emulator).

## 11. API Health Check
Test backend and database status:
```bash
GET http://localhost:5000/api/health
```
Response:
```json
{
  "success": true,
  "message": "Farm-to-Market API is running",
  "database": "connected"
}
```

## 12. Current Phase
Phase 1 establishes the mobile, backend, database and API foundation. Authentication, dataset ingestion, ML crop-name matching, recommendation logic, logistics calculations and advanced decision-support features will be implemented in subsequent phases.

## 13. Future Implementation Phases
* **Phase 2**: Authentication & Onboarding (Farmer & Buyer Registration, Login, Token Management).
* **Phase 3**: Dataset Ingestion & Commodity Catalog (AGMARKNET integration, ML crop name normalization).
* **Phase 4**: Farmer Crop Management & Buyer Demand Registry.
* **Phase 5**: Intelligence & Recommendation Engine (Distance calculation, net return optimization, buyer matching, quantity allocation).
* **Phase 6**: Decision Support UI & Feedback System (Interactive dashboards, price trends, buyer ratings).
