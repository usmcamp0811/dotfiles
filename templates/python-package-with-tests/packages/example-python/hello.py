import click
import numpy as np
import plotext as plt
from sklearn.linear_model import LinearRegression


@click.command()
@click.option("--points", default=100, help="Number of data points.")
def main(points):
    np.random.seed(0)
    x = np.random.rand(points, 1) * 10
    y = 2.5 * x + np.random.randn(points, 1) * 2

    model = LinearRegression()
    model.fit(x, y)

    x_test = np.linspace(0, 10, 100).reshape(-1, 1)
    y_pred = model.predict(x_test)

    plt.scatter(x.flatten(), y.flatten(), label="Data")
    plt.plot(x_test.flatten(), y_pred.flatten(), label="Prediction")
    plt.title("Linear Regression")
    plt.xlabel("x")
    plt.ylabel("y")
    plt.show()


if __name__ == "__main__":
    main()
