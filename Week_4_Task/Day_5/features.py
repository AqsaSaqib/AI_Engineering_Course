# features.py - the 8 new features from Day 3
# This is in its own file so the saved model can be loaded anywhere (notebook, inference.py, tests).
import numpy as np
import pandas as pd


def add_features(data):
    data = data.copy()
    data["age_group"] = pd.cut(data["age"], bins=[0, 25, 35, 45, 55, 65, 100],
                               labels=["17-25", "26-35", "36-45", "46-55", "56-65", "66+"]).astype(str)
    data["hours_group"] = pd.cut(data["hours.per.week"], bins=[0, 34, 40, 60, 100],
                                 labels=["part-time", "full-time", "overtime", "very-long"]).astype(str)
    data["has_capital_gain"] = (data["capital.gain"] > 0).astype(int)
    data["log_capital_gain"] = np.log1p(data["capital.gain"])
    data["log_capital_loss"] = np.log1p(data["capital.loss"])
    data["higher_education"] = (data["education.num"] >= 13).astype(int)
    data["edu_x_hours"] = data["education.num"] * data["hours.per.week"]
    data["is_married"] = data["marital.status"].isin(["Married-civ-spouse", "Married-AF-spouse"]).astype(int)
    return data
