# Week 4 Day 4 — Model Tuning, Regularization & Reproducible Pipelines

**Dataset:** UCI Adult (Census Income)

## What is this?
I tuned my two best models from Day 3, checked them for overfitting, chose the best threshold, and saved the final model.
The goal is still the same: predict if a person earns more than 50K per year.

## Folder structure
```
Day_4/
├── Saved_Pipelines/
│   └── final_model.joblib
├── adult.csv
├── README.md
├── Week4_Day4_Report.pdf
└── Week4_Day4_Task.ipynb
```

## Files
| File | What it is |
|---|---|
| `Week4_Day4_Task.ipynb` | The notebook with all 5 tasks |
| `Week4_Day4_Report.pdf` | The tuning report (2 pages) |
| `adult.csv` | The dataset |
| `Saved_Pipelines/final_model.joblib` | The final model (features + preprocessing + model) and its threshold |
| `README.md` | This file |

## How to run
1. Open [Google Colab](https://colab.research.google.com).
2. Click **File → Upload notebook** and choose `Week4_Day4_Task.ipynb`.
3. Click **Runtime → Run all**.
4. Upload `adult.csv` when the "Choose Files" button appears.
The notebook takes about 15 minutes. All random steps use `random_state=42`, so the results are the same every time.

## What I did
1. **Pipeline:** new features → preprocessing → model, with `random_state=42` everywhere.
2. **Search:** grid search for Logistic Regression and randomized search (50 tries) for Gradient Boosting.
3. **Diagnostics:** learning curve, effect of `C`, and effect of `max_depth`.
4. **Calibration & threshold:** checked the probabilities and picked the best threshold.
5. **Final test:** tested the final model on the hold-out test set and saved it.

## Best settings
| Model | Best settings | CV F1 |
|---|---|---|
| Logistic Regression | `penalty = l2`, `C = 10` | 0.678 |
| Gradient Boosting | `learning_rate = 0.03`, `max_iter = 300`, `max_depth = None`, `l2_regularization = 10` | 0.715 |

## Final results (hold-out test set)
Final model: tuned Gradient Boosting with threshold **0.40** (no calibration, because it did not help).

| Metric | Score |
|---|---|
| Accuracy | 0.864 |
| Precision | 0.710 |
| Recall | 0.734 |
| F1 | 0.722 |
| ROC AUC | 0.923 |
| PR AUC | 0.822 |

For comparison: Day 1 baseline F1 = 0.505, Day 2 Logistic Regression F1 = 0.667.

## How to use the saved model
The model uses my `add_features` function, so first run the `add_features` cell from the notebook (or copy it). Then:

```python
import joblib

saved = joblib.load("Saved_Pipelines/final_model.joblib")

proba = saved["model"].predict_proba(new_people)[:, 1]
prediction = (proba >= saved["threshold"]).astype(int)   # 1 = earns >50K
```
`new_people` must be a table with the same columns as `adult.csv`.

## Note for production
- Expect an F1 around 0.72: about 7 in 10 people we contact are real high earners, and we find about 3 in 4 of all high earners.
- The data is from 1994, so the model must be checked and retrained on new data before real use.