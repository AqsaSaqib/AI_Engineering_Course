# inference.py - use the saved model on new people
#
# From the command line:
#     python inference.py new_people.csv
#
# From Python:
#     from inference import predict
#     predict({"age": 45, "workclass": "Private", ...})
#
# It returns: the chance of >50K, the prediction (using my threshold) and the top 3 reasons.

import os
import sys
import warnings

import joblib
import numpy as np
import pandas as pd
import shap

from features import add_features   # the saved pipeline needs this file

warnings.filterwarnings("ignore")

# ---------- Load the saved model once ----------
HERE = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(HERE, "Saved_Pipelines", "final_model.joblib")

saved = joblib.load(MODEL_PATH)
model = saved["model"]            # features + preprocessing + Gradient Boosting
threshold = saved["threshold"]    # 0.40
explainer = shap.TreeExplainer(model.named_steps["model"])

# ---------- The columns the model needs ----------
NUMERIC_COLUMNS = ["age", "education.num", "capital.gain", "capital.loss", "hours.per.week"]
CATEGORY_COLUMNS = ["workclass", "marital.status", "occupation", "relationship",
                    "race", "sex", "native.country"]
REQUIRED_COLUMNS = NUMERIC_COLUMNS + CATEGORY_COLUMNS

# Categories the model saw in training (to find unseen ones)
preprocess = model.named_steps["preprocess"]
encoder = preprocess.named_transformers_["cat"].named_steps["onehot"]
model_cat_columns = preprocess.transformers_[1][2]
KNOWN_CATEGORIES = {col: set(cats) for col, cats in zip(model_cat_columns, encoder.categories_)}

# Easy feature names, for example "cat__sex_Female" -> "sex_Female"
FEATURE_NAMES = [name.split("__", 1)[1] for name in preprocess.get_feature_names_out()]


def to_dataframe(data):
    """Accept a CSV path, one person (dict), many people (list of dicts) or a table."""
    if isinstance(data, str):
        return pd.read_csv(data)
    if isinstance(data, dict):
        return pd.DataFrame([data])
    if isinstance(data, list):
        return pd.DataFrame(data)
    return pd.DataFrame(data).copy()


def validate_input(df):
    """Check the columns and clean the values."""
    missing = [col for col in REQUIRED_COLUMNS if col not in df.columns]
    if missing:
        raise ValueError(f"Missing columns: {missing}")
    if len(df) == 0:
        raise ValueError("The input has no rows")

    df = df[REQUIRED_COLUMNS].copy()
    df = df.replace("?", np.nan)
    for col in NUMERIC_COLUMNS:
        df[col] = pd.to_numeric(df[col], errors="coerce")   # text in a number column becomes missing
    return df


def find_unseen(df):
    """For each row, list the categories the model never saw in training."""
    notes = []
    for _, row in df.iterrows():
        unseen = [f"{col}={row[col]}" for col in CATEGORY_COLUMNS
                  if pd.notna(row[col]) and row[col] not in KNOWN_CATEGORIES[col]]
        notes.append(", ".join(unseen))
    return notes


def top_3_reasons(df):
    """The 3 features that pushed each prediction the most (SHAP values)."""
    ready = model[:-1].transform(df)                 # make features + preprocessing
    shap_values = explainer.shap_values(ready)
    reasons = []
    for row in shap_values:
        top = np.argsort(-np.abs(row))[:3]
        reasons.append("; ".join(f"{FEATURE_NAMES[j]} ({row[j]:+.2f})" for j in top))
    return reasons


def predict(data):
    df = validate_input(to_dataframe(data))
    proba = model.predict_proba(df)[:, 1]
    return pd.DataFrame({
        "probability": proba.round(3),
        "prediction": (proba >= threshold).astype(int),     # 1 = earns >50K
        "top_3_features": top_3_reasons(df),
        "note": find_unseen(df),
    })


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python inference.py new_people.csv")
        sys.exit(1)
    results = predict(sys.argv[1])
    print(results.to_string())
    results.to_csv("predictions.csv", index=False)
    print("Saved: predictions.csv")
