# Week 4 Day 1 — ML Foundations
**Topic:** Problem Framing, Hold-Out Test & Baseline
**Dataset:** UCI Adult (Census Income)


## What is this project?
I use census data to predict if a person earns more than 50K per year.
Today I did not build a real model. I only prepared the data, made a test set, and built two simple baselines to get a score to beat.

## Files
| File | What it is |
|---|---|
| `Week4_Day1_Simple.ipynb` | The notebook with all 5 tasks |
| `adult.csv` | The dataset (32,561 rows, 15 columns) |
| `Week4_Day1_Summary.pdf` | One-page summary of the work |
| `README.md` | This file |

## How to run
1. Open [Google Colab](https://colab.research.google.com).
2. Click **File → Upload notebook** and choose `Week4_Day1_Simple.ipynb`.
3. Click **Runtime → Run all**.
4. When the "Choose Files" button appears, upload `adult.csv`.

Libraries used: `pandas`, `numpy`, `matplotlib`, `scikit-learn`. Colab already has all of them.

## What I did
1. **Problem and metric:** the target is `income`. `>50K` is the positive class. Only 24% of people are positive, so I chose the **F1 score** instead of accuracy.
2. **EDA:** changed `?` to NaN, checked shape, column types, summaries and value counts, and made histograms and bar plots.
3. **Split:** 80% train and 20% hold-out test, stratified, with `random_state=42`.
4. **Baselines:** a majority-class predictor and one simple rule (`education.num >= 13`).
5. **Error analysis:** looked at 10 false positives and 10 false negatives and listed what to fix next.

## Results (hold-out test set)
| Baseline | Accuracy | Precision | Recall | F1 | ROC AUC | PR AUC |
|---|---|---|---|---|---|---|
| Majority class (always <=50K) | 0.759 | 0.000 | 0.000 | 0.000 | 0.500 | 0.241 |
| Rule: `education.num >= 13` | 0.758 | 0.498 | 0.511 | 0.505 | 0.674 | 0.372 |
The education rule wins. The majority baseline has 76% accuracy but finds zero high earners, so its F1 is 0.

## What I learned
- Accuracy can be misleading when the classes are imbalanced.
- A hold-out test set must stay untouched until the final check.
- Education alone is not enough. The rule makes mistakes on young graduates (false positives) and on older married people without a degree (false negatives).

## Next steps
- Fill missing values in `workclass`, `occupation` and `native.country`.
- Change text columns to numbers (one-hot encoding).
- Fix the skewed columns `capital.gain` and `capital.loss`.
- Drop `education` (same as `education.num`) and `fnlwgt`.
- Train a real model and try to beat F1 = 0.51. My target is 0.60 or more.