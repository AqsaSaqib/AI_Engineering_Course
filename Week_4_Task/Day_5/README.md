# Week 4 Day 5 — Capstone: Ensembles, Imbalance, Interpretability & Deployment

**Dataset:** UCI Adult (Census Income)

## What is this?
My mini capstone. I compared ensemble models, tested ways to handle class imbalance, explained the model with SHAP, checked fairness, and made the final model ready to use with an inference script.
The goal is still the same: predict if a person earns more than 50K per year.

## Folder structure
```
Day_5/
├── Saved_Pipelines/
│   └── final_model.joblib
├── adult.csv
├── features.py
├── inference.py
├── test_inference.py
├── README.md
├── Week4_Day5_Monitoring_Checklist.pdf
├── Week4_Day5_Report.pdf
└── Week4_Day5_Task.ipynb
```

## Files
| File | What it is |
|---|---|
| `Week4_Day5_Task.ipynb` | The notebook with all 5 tasks |
| `Week4_Day5_Report.pdf` | The executive report (2 pages) |
| `Week4_Day5_Monitoring_Checklist.pdf` | What to watch after launch (1 page) |
| `features.py` | The 8 new features (the saved model needs this file) |
| `inference.py` | Uses the saved model on new people |
| `test_inference.py` | Basic tests for `inference.py` |
| `Saved_Pipelines/final_model.joblib` | The final model (features + preprocessing + model) and its threshold |
| `adult.csv` | The dataset |
| `README.md` | This file |

## How to run the notebook
1. Open [Google Colab](https://colab.research.google.com).
2. Click **File → Upload notebook** and choose `Week4_Day5_Task.ipynb`.
3. Click **Runtime → Run all**.
4. Upload `adult.csv` when the "Choose Files" button appears.

It takes about 10 minutes. It creates `features.py`, `inference.py`, `test_inference.py` and `Saved_Pipelines/final_model.joblib`.

Extra libraries: `shap` and `imbalanced-learn` (Colab usually has them; the notebook installs them if needed).

## How to use the model
Keep `features.py`, `inference.py` and the `Saved_Pipelines` folder together. Use the same scikit-learn version as in Colab (it is printed at the top of the notebook).

From the command line:
```
python inference.py new_people.csv
```

From Python:
```python
from inference import predict

predict({"age": 45, "workclass": "Private", "education.num": 13,
         "marital.status": "Married-civ-spouse", "occupation": "Exec-managerial",
         "relationship": "Husband", "race": "White", "sex": "Male",
         "capital.gain": 0, "capital.loss": 0, "hours.per.week": 50,
         "native.country": "United-States"})
```
It returns the **probability**, the **prediction** (1 = earns >50K, using threshold 0.40), the **top 3 features** that pushed the prediction, and a **note** if a category was never seen in training.

## How to run the tests
```
python test_inference.py
```
The 5 tests check: a normal person, a missing column, an unseen category, a missing value and a CSV file.

## Results (hold-out test set)
| Model | F1 | ROC AUC |
|---|---|---|
| Day 1 simple rule | 0.505 | 0.674 |
| Logistic Regression | 0.678 | 0.909 |
| Random Forest | 0.681 | 0.913 |
| Stacking | 0.711 | 0.922 |
| **Final: Gradient Boosting, threshold 0.40** | **0.722** | **0.923** |

## What I found

- **Gradient Boosting** is the best model. Stacking scores the same but is slower.
- **Class imbalance:** class weight, undersampling and SMOTE did not make the model better at ranking people. I kept no resampling and used threshold 0.40.
- **Top features:** marital status, age, capital gain and education.
- **Fairness:** about equal for women and men (F1 0.713 vs 0.723), lower for some smaller race groups.
- **Next step:** an A/B test against the current way of choosing people, then monitoring with the checklist.