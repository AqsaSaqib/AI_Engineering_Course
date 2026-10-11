# Week 4 Day 2 — Core Supervised Learning

**Dataset:** UCI Adult (Census Income)

## What is this?
I trained two models to predict if a person earns more than 50K per year.
Then I compared them with my Day 1 baseline.

## Folder structure
```
Day_2/
├── Saved_Pipelines/
│   ├── logistic_model.joblib
│   └── preprocessor.joblib
├── adult.csv
├── README.md
├── Week4_Day2_Summary.pdf
└── Week4_Day2_Task.ipynb
```

## Files
| File | What it is |
|---|---|
| `Week4_Day2_Task.ipynb` | The notebook with all 5 tasks |
| `Week4_Day2_Summary.pdf` | The write-up (2 pages) |
| `adult.csv` | The dataset |
| `Saved_Pipelines/preprocessor.joblib` | The saved preprocessing steps |
| `Saved_Pipelines/logistic_model.joblib` | The saved best model (preprocessing + Logistic Regression) |
| `README.md` | This file |

## How to run
1. Open [Google Colab](https://colab.research.google.com).
2. Click **File → Upload notebook** and choose `Week4_Day2_Task.ipynb`.
3. Click **Runtime → Run all**.
4. Upload `adult.csv` when the "Choose Files" button appears.

## What I did
1. **Preprocessing:** filled missing values, scaled the numbers, and changed text to 0/1 columns.
2. **Models:** trained Logistic Regression and a Decision Tree on the training data.
3. **Testing:** checked both models on the hold-out test set.
4. **Looking inside:** checked which features matter and if the tree overfits.
5. **Decision:** picked the model to continue with and saved it.

## Results (hold-out test set)
| Model | Accuracy | Precision | Recall | F1 | ROC AUC | PR AUC |
|---|---|---|---|---|---|---|
| Day 1 baseline | 0.758 | 0.498 | 0.511 | 0.505 | 0.674 | 0.372 |
| Logistic Regression | 0.853 | 0.735 | 0.610 | 0.667 | 0.904 | 0.767 |
| Decision Tree | 0.817 | 0.628 | 0.592 | 0.610 | 0.758 | 0.493 |

## What I found
- Both models are better than the Day 1 baseline.
- **Logistic Regression is the best model.**
- The Decision Tree overfits: accuracy is 0.98 on train but 0.82 on test.
- Both models miss high earners more often than they pick wrong people.

## Model I will continue with
**Logistic Regression**, because it has the best scores, does not overfit, and is easy to explain.

## Saved pipelines

The notebook saves two files. I put them in the `Saved_Pipelines` folder so I can use them again on Day 3.

```python
import joblib

model = joblib.load("Saved_Pipelines/logistic_model.joblib")
predictions = model.predict(X_test)
```