import argparse

import maya


def get_time_difference(date1, date2):
    dt1 = maya.when(date1)
    dt2 = maya.when(date2)
    return abs((dt2 - dt1).days)


def main():
    parser = argparse.ArgumentParser(
        description="Calculate the number of days between two dates."
    )
    parser.add_argument("date1", type=str, help="First date in YYYY-MM-DD format")
    parser.add_argument("date2", type=str, help="Second date in YYYY-MM-DD format")

    args = parser.parse_args()
    days_difference = get_time_difference(args.date1, args.date2)

    print(
        f"The number of days between {args.date1} and {args.date2} is {days_difference} days."
    )


if __name__ == "__main__":
    main()
