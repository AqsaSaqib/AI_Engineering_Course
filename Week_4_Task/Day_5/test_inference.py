# test_inference.py - basic tests for inference.py
# Run with:  python test_inference.py   (pytest test_inference.py also works)
import os
import tempfile

import pandas as pd

from inference import predict

PERSON = {
    "age": 45, "workclass": "Private", "education.num": 13,
    "marital.status": "Married-civ-spouse", "occupation": "Exec-managerial",
    "relationship": "Husband", "race": "White", "sex": "Male",
    "capital.gain": 0, "capital.loss": 0, "hours.per.week": 50,
    "native.country": "United-States",
}


def test_normal_person():
    result = predict(PERSON)
    assert len(result) == 1
    assert 0 <= result["probability"][0] <= 1
    assert result["prediction"][0] in (0, 1)
    assert len(result["top_3_features"][0].split("; ")) == 3


def test_missing_column():
    person = dict(PERSON)
    del person["age"]
    try:
        predict(person)
        assert False, "predict() should fail when a column is missing"
    except ValueError as error:
        assert "age" in str(error)


def test_unseen_category():
    person = dict(PERSON)
    person["occupation"] = "Astronaut"          # never seen in training
    result = predict(person)
    assert 0 <= result["probability"][0] <= 1   # still works
    assert "Astronaut" in result["note"][0]     # and tells us about it


def test_missing_value():
    person = dict(PERSON)
    person["workclass"] = "?"                   # "?" means missing in this dataset
    result = predict(person)
    assert 0 <= result["probability"][0] <= 1


def test_csv_input():
    path = os.path.join(tempfile.mkdtemp(), "people.csv")
    pd.DataFrame([PERSON, PERSON, PERSON]).to_csv(path, index=False)
    result = predict(path)
    assert len(result) == 3


if __name__ == "__main__":
    tests = [test_normal_person, test_missing_column, test_unseen_category,
             test_missing_value, test_csv_input]
    for test in tests:
        test()
        print("PASSED:", test.__name__)
    print("All", len(tests), "tests passed")
