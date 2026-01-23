import os
import pandas as pd
import joblib
import xgboost as xgb

from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import classification_report, accuracy_score

# ================= CONFIG ================= #

DATA_PATH = "D:/Laptop/college/sem8/Capstone project/Aurora/data/Menstrual_Health_and_PCOD_Risk_Detection _Dataset.csv"
MODEL_DIR = "artifacts"

os.makedirs(MODEL_DIR, exist_ok=True)

# ================= LOAD DATA ================= #

print("📂 Loading dataset...")
assert os.path.exists(DATA_PATH), "❌ Dataset file not found"

df = pd.read_csv(DATA_PATH)

print("Shape:", df.shape)
print(df.head())

# ================= BASIC CLEANING ================= #

df = df.drop_duplicates()

# Normalize Unusual_Bleeding
df["Unusual_Bleeding"] = (
    df["Unusual_Bleeding"]
    .astype(str)
    .str.lower()
    .map({"no": 0, "yes": 1})
)

# Drop noisy / unusable columns
df.drop(columns=["Height", "Income"], inplace=True)

# ================= TARGET CLEANING ================= #
# Raw pain scores are inconsistent (1,2,3,4,4.2,4.5,5)

PAIN_MAP = {
    1.0: 0,
    2.0: 1,
    3.0: 2,
    4.0: 3,
    4.2: 4,
    4.5: 5,
    5.0: 6
}

df["Menses_score"] = df["Menses_score"].map(PAIN_MAP)

# Drop rows where mapping failed
df = df.dropna()
df["Menses_score"] = df["Menses_score"].astype(int)

print("\nInitial target distribution:")
print(df["Menses_score"].value_counts())

# ================= REMOVE RARE CLASSES ================= #
# Classes with <3 samples are not learnable

class_counts = df["Menses_score"].value_counts()
valid_classes = class_counts[class_counts >= 3].index

print("\nKeeping classes:", list(valid_classes))

df = df[df["Menses_score"].isin(valid_classes)]

# ================= RE-ENCODE TARGET (CONTIGUOUS) ================= #
# Required by XGBoost multiclass

label_encoder = LabelEncoder()
df["Menses_score"] = label_encoder.fit_transform(df["Menses_score"])

print("\nFinal class mapping:")
for original, encoded in zip(label_encoder.classes_, range(len(label_encoder.classes_))):
    print(f"{original} -> {encoded}")

# ================= FEATURES / TARGET ================= #

X = df.drop(columns=["Menses_score"])
y = df["Menses_score"]

print("\nFinal target distribution:")
print(y.value_counts())

# ================= TRAIN / TEST SPLIT ================= #

X_train, X_test, y_train, y_test = train_test_split(
    X,
    y,
    test_size=0.2,
    random_state=42,
    stratify=y
)

# ================= MODEL ================= #

model = xgb.XGBClassifier(
    objective="multi:softmax",
    num_class=len(y.unique()),
    n_estimators=300,
    max_depth=5,
    learning_rate=0.05,
    subsample=0.8,
    colsample_bytree=0.8,
    eval_metric="mlogloss",
    random_state=42
)

print("\n🚀 Training XGBoost model...")
model.fit(X_train, y_train)

# ================= EVALUATION ================= #

y_pred = model.predict(X_test)

print("\n📊 Accuracy:", accuracy_score(y_test, y_pred))
print("\n📊 Classification Report:\n")
print(classification_report(y_test, y_pred))

# ================= SAVE ARTIFACTS ================= #

joblib.dump(model, os.path.join(MODEL_DIR, "xgb_menstrual_pain_model.pkl"))
joblib.dump(label_encoder, os.path.join(MODEL_DIR, "label_encoder.pkl"))

print("\n✅ Model training complete")
print("📁 Artifacts saved to:", MODEL_DIR)
