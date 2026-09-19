# FarmFlow Agricultural Price Prediction ML Service

Microservice exposing the trained CatBoost agricultural commodity price forecasting model for the FarmFlow platform.

---

## 1. Technology Stack
- **Language**: Python 3.12+
- **Framework**: FastAPI + Uvicorn
- **Model Engine**: CatBoost (`CatBoostRegressor`)
- **Data Preprocessing**: Pandas & NumPy
- **Default Port**: `8000`

---

## 2. Model Architecture & Input Schema

The trained model [`agri_price_model.pkl`](./agri_price_model.pkl) requires the following 11 features:

| Feature Name | Type | Description / Example |
| :--- | :--- | :--- |
| `District Name` | String | e.g., `Krishna`, `Guntur`, `Jabalpur` |
| `Market Name` | String | e.g., `Mylavaram`, `Tadikonda`, `Paatan` |
| `Commodity` | String | e.g., `Tomato`, `Cotton`, `Maize`, `Wheat` |
| `Variety` | String | e.g., `Other`, `Local`, `Hybrid` |
| `Grade` | String | e.g., `FAQ`, `Grade A`, `Medium` |
| `State` | String | e.g., `Andhra Pradesh`, `Madhya Pradesh` |
| `Year` | Integer | e.g., `2025`, `2026` |
| `Month` | Integer | `1` to `12` |
| `Day` | Integer | `1` to `31` |
| `DayOfWeek` | Integer | `0` (Monday) to `6` (Sunday) |
| `DayOfYear` | Integer | `1` to `366` |

**Target Variable**: Modal Wholesale Market Price (`modalPrice`) in **₹ / Quintal**.

---

## 3. Local Setup & Execution

### Step 1: Create Virtual Environment
```bash
cd ml_service
python -m venv .venv
```

### Step 2: Activate Environment & Install Dependencies
On Windows PowerShell:
```powershell
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### Step 3: Run the FastAPI Service
```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

---

## 4. API Endpoints

### Health Check
- **Endpoint**: `GET /health`
- **Response**:
```json
{
  "success": true,
  "service": "FarmFlow Agricultural Price ML Service",
  "modelLoaded": true,
  "unit": "Quintal"
}
```

### Price Prediction
- **Endpoint**: `POST /predict`
- **Request Body**:
```json
{
  "commodity": "Tomato",
  "state": "Andhra Pradesh",
  "district": "Krishna",
  "market": "Mylavaram",
  "variety": "Other",
  "grade": "FAQ",
  "date": "2025-08-15"
}
```
- **Response**:
```json
{
  "success": true,
  "prediction": {
    "commodity": "Tomato",
    "state": "Andhra Pradesh",
    "district": "Krishna",
    "market": "Mylavaram",
    "variety": "Other",
    "grade": "FAQ",
    "targetDate": "2025-08-15",
    "predictedPrice": 8450.0,
    "unit": "Quintal",
    "formattedPrice": "₹8,450 / Quintal",
    "modelVersion": "agri_price_model_v1"
  }
}
```
