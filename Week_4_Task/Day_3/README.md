# Week 4 Day 3 — Feature Engineering, Cross-Validation & Model Comparison

**Dataset:** UCI Adult (Census Income)

## What is this?

I made new features and compared three models with cross-validation.
The goal is still the same: predict if a person earns more than 50K per year.

## Folder structure

```
Day_3/
├── adult.csv
├── feature_dictionary.csv
├── README.md
├── Week4_Day3_Summary.pdf
└── Week4_Day3_Task.ipynb
```

## Files

| File | What it is |
|---|---|
| `Week4_Day3_Task.ipynb` | The notebook with all 5 tasks |
| `Week4_Day3_Summary.pdf` | The summary (2 pages) |
| `adult.csv` | The dataset |
| `feature_dictionary.csv` | The list of my new features (made by the notebook) |
| `README.md` | This file |

## How to run

1. Open [Google Colab](https://colab.research.google.com).
2. Click **File → Upload notebook** and choose `Week4_Day3_Task.ipynb`.
3. Click **Runtime → Run all**.
4. Upload `adult.csv` when the "Choose Files" button appears.

The notebook takes about 3 to 5 minutes to finish.

## What I did

1. **New features:** made 8 new features from the old columns.
2. **Pipeline:** added the new features as the first step of the pipeline.
3. **Cross-validation:** compared 3 models with 5 folds.
4. **Statistical test:** checked if the best model is really better.
5. **Feature selection:** checked if fewer features work better.

## My new features

| Feature | How it is made |
|---|---|
| `age_group` | age cut into 6 groups |
| `hours_group` | hours per week cut into 4 groups |
| `has_capital_gain` | 1 if capital gain is more than 0 |
| `log_capital_gain` | log of capital gain |
| `log_capital_loss` | log of capital loss |
| `higher_education` | 1 if Bachelors degree or higher |
| `edu_x_hours` | education number × hours per week |
| `is_married` | 1 if the person is married |

## Results (5-fold cross-validation)

| Model | F1 | ROC AUC |
|---|---|---|
| Logistic Regression | 0.676 ± 0.007 | 0.914 ± 0.002 |
| Random Forest | 0.660 ± 0.011 | 0.895 ± 0.002 |
| Gradient Boosting | 0.714 ± 0.007 | 0.928 ± 0.002 |

## What I found

- **Gradient Boosting is the best model.**
- The difference between Gradient Boosting and Logistic Regression is real (p-value = 0.0005).
- The new features help Logistic Regression (F1 0.658 → 0.676). They do not change Gradient Boosting.
- `is_married`, `edu_x_hours` and `log_capital_gain` are the most useful new features.
- Keeping only 30 columns makes the score lower (0.714 → 0.692), so I keep all the features.
