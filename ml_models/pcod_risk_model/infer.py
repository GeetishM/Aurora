import joblib
import pandas as pd

# ================= CONFIG ================= #

MODEL_PATH = "artifacts/xgb_menstrual_pain_model.pkl"
ENCODER_PATH = "artifacts/label_encoder.pkl"

# ================= LOAD ARTIFACTS ================= #

model = joblib.load(MODEL_PATH)
label_encoder = joblib.load(ENCODER_PATH)

# ================= PREDICTION FUNCTION ================= #

def predict_menstrual_pain(features: dict):
    """
    features: dict with keys matching training columns
    Example:
    {
        "number_of_peak": 3,
        "Age": 22,
        "Length_of_cycle": 30,
        ...
    }
    """

    df = pd.DataFrame([features])

    pred_class = model.predict(df)[0]
    original_label = label_encoder.inverse_transform([pred_class])[0]

    return {
        "encoded_class": int(pred_class),
        "original_pain_class": int(original_label)
    }


# ================= TEST ================= #

if __name__ == "__main__":
    sample_input = {
        "number_of_peak": 3,
        "Age": 22,
        "Length_of_cycle": 30,
        "Estimated_day_of_ovulution": 15,
        "Length_of_Leutal_Phase": 12,
        "Length_of_menses": 5,
        "Unusual_Bleeding": 0,
        "Weight": 55,
        "BMI": 21.5,
        "Mean_of_length_of_cycle": 30
    }

    result = predict_menstrual_pain(sample_input)
    print("Prediction:", result)
