import os
import pickle
from datetime import datetime
from typing import Optional
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import pandas as pd
import numpy as np

app = FastAPI(
    title="FarmFlow Agricultural Price ML Service",
    description="Microservice exposing the trained CatBoost agricultural commodity price prediction model.",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

MODEL_PATH = os.path.join(os.path.dirname(__file__), "agri_price_model.pkl")

# Global model references
model_wrapper = None
model = None
expected_columns = [
    "District Name",
    "Market Name",
    "Commodity",
    "Variety",
    "Grade",
    "State",
    "Year",
    "Month",
    "Day",
    "DayOfWeek",
    "DayOfYear",
]
categorical_columns = ["District Name", "Market Name", "Commodity", "Variety", "Grade", "State"]


@app.on_event("startup")
def load_agri_model():
    global model_wrapper, model, expected_columns, categorical_columns
    print("\n=======================================================")
    print("[ML] Loading agricultural price model from:", MODEL_PATH)
    if not os.path.exists(MODEL_PATH):
        print(f"[ML ERROR] Model file not found at {MODEL_PATH}")
        return

    try:
        with open(MODEL_PATH, "rb") as f:
            model_wrapper = pickle.load(f)

        if isinstance(model_wrapper, dict):
            model = model_wrapper.get("model")
            if "columns" in model_wrapper:
                expected_columns = list(model_wrapper["columns"])
            if "categorical_columns" in model_wrapper:
                categorical_columns = list(model_wrapper["categorical_columns"])
        else:
            model = model_wrapper

        print("[ML] Model loaded successfully")
        print(f"[ML] Expected Features ({len(expected_columns)}):", expected_columns)
        print(f"[ML] Categorical Features ({len(categorical_columns)}):", categorical_columns)
        print("[ML] ML service running on port 8000")
        print("=======================================================\n")
    except Exception as e:
        print(f"[ML ERROR] Failed to load model: {e}")
        model = None


class PredictionRequest(BaseModel):
    commodity: str = Field(..., description="Commodity name (e.g. Tomato, Cotton, Maize, Wheat)")
    state: Optional[str] = Field("Andhra Pradesh", description="State name")
    district: Optional[str] = Field("Krishna", description="District name")
    market: Optional[str] = Field(None, description="Wholesale market / APMC Mandi name")
    variety: Optional[str] = Field("Other", description="Crop variety (e.g. Other, Local, Hybrid)")
    grade: Optional[str] = Field("FAQ", description="Quality grade (e.g. FAQ, Grade A, Medium)")
    date: Optional[str] = Field(None, description="Forecast date in ISO format (YYYY-MM-DD)")


@app.get("/health")
def health_check():
    return {
        "success": True,
        "service": "FarmFlow Agricultural Price ML Service",
        "modelLoaded": model is not None,
        "features": expected_columns,
        "categoricalFeatures": categorical_columns,
        "unit": "Quintal",
    }


@app.post("/predict")
def predict_price(req: PredictionRequest):
    if model is None:
        raise HTTPException(
            status_code=503,
            detail="Agricultural price prediction model is currently unavailable."
        )

    commodity_name = req.commodity.strip() if req.commodity else ""
    if not commodity_name:
        raise HTTPException(status_code=400, detail="Commodity name is required.")

    # Target Date parsing for temporal feature extraction
    if req.date and req.date.strip():
        try:
            dt = datetime.fromisoformat(req.date.strip())
        except ValueError:
            dt = datetime.now()
    else:
        dt = datetime.now()

    state_name = req.state.strip() if req.state and req.state.strip() else "Andhra Pradesh"
    district_name = req.district.strip() if req.district and req.district.strip() else "Krishna"
    market_name = req.market.strip() if req.market and req.market.strip() else district_name
    variety_name = req.variety.strip() if req.variety and req.variety.strip() else "Other"
    grade_name = req.grade.strip() if req.grade and req.grade.strip() else "FAQ"

    # Assemble feature row matching exact model schema
    row = {
        "District Name": str(district_name),
        "Market Name": str(market_name),
        "Commodity": str(commodity_name),
        "Variety": str(variety_name),
        "Grade": str(grade_name),
        "State": str(state_name),
        "Year": int(dt.year),
        "Month": int(dt.month),
        "Day": int(dt.day),
        "DayOfWeek": int(dt.weekday()),  # 0=Monday, 6=Sunday
        "DayOfYear": int(dt.timetuple().tm_yday),
    }

    df = pd.DataFrame([row])

    # Reorder columns to ensure exact expected alignment
    if expected_columns:
        for col in expected_columns:
            if col not in df.columns:
                df[col] = "Other"
        df = df[expected_columns]

    try:
        raw_prediction = model.predict(df)
        pred_value = float(raw_prediction[0])

        if np.isnan(pred_value) or np.isinf(pred_value):
            raise HTTPException(
                status_code=500,
                detail="Model produced an invalid non-finite prediction."
            )

        # Price cannot be negative
        predicted_price = max(0.0, round(pred_value, 2))

        return {
            "success": True,
            "prediction": {
                "commodity": commodity_name,
                "state": state_name,
                "district": district_name,
                "market": market_name,
                "variety": variety_name,
                "grade": grade_name,
                "targetDate": dt.strftime("%Y-%m-%d"),
                "predictedPrice": predicted_price,
                "unit": "Quintal",
                "formattedPrice": f"₹{predicted_price:,.0f} / Quintal",
                "modelVersion": "agri_price_model_v1",
            },
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Prediction failed: {str(e)}"
        )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
