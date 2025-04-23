import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from sklearn.linear_model import LinearRegression


def main():
    # Generate data
    np.random.seed(0)
    x = np.random.rand(100, 1) * 10
    y = 2.5 * x + np.random.randn(100, 1) * 2

    # Fit model
    model = LinearRegression()
    model.fit(x, y)

    # Predict
    x_test = np.linspace(0, 10, 100).reshape(-1, 1)
    y_pred = model.predict(x_test)

    # Plot
    df = pd.DataFrame({"x": x.flatten(), "y": y.flatten()})
    plt.scatter(df["x"], df["y"], label="Data")
    plt.plot(x_test, y_pred, color="red", label="Prediction")
    plt.legend()
    plt.xlabel("x")
    plt.ylabel("y")
    plt.title("Linear Regression")
    plt.show()


if __name__ == "__main__":
    main()
