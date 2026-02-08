+++
author = "Matthew Camp"
title = "Automated Testing (w/ Gitlab CI/CD & Python)"
date = "2020-07-09"
description = "A comprehensive guide to setting up automated testing for a Python project using GitLab CI/CD."
tags = [
    "Python",
    "GitLab",
    "CI/CD",
    "automated testing",
    "Poetry",
    "pytest"
]
+++

# Automated Testing

These notes will cover how to start a brand new Python project from scratch, initialize a Git repository inside of it, and how to configure the
repository to automatically test all your code every time you push to Gitlab. This will be assumed you have some familiarity with the Python
programming language, and Git version control system. The tutorial will be broken up into two parts, the first covering how to configure
a new project in Python, complete with unit tests, and a second part covering how to make Gitlab automatically run your test scripts
every time a change is pushed to your remote repository.

_NOTE: For brevity this tutorial is only covering how to do testing in Python, but much of the Gitlab Runner stuff is language agnostic and can be easily applied to your language of choice_

**Requirements**

- [Gitlab Account](https://gitlab.com/users/sign_up)
- [Git](https://git-scm.com/downloads)
- [Python >=3.6](https://www.python.org/downloads/)
  - [poetry](https://python-poetry.org/)
  - [pytest](https://docs.pytest.org/en/stable/)
  - [pytest-cov](https://pytest-cov.readthedocs.io/en/latest/)
  - [snapshottest](https://github.com/medmunds/snapshottest)

## Creating a New Project

We are going to use Poetry to create a new Python Project. I chose Poetry because it does a number of things to make dependecy management
in Python much simpiler. It is still a work in progress and some aspects of it are slow but overall it provides a very low barrier of
entry for adhearing to some best practices, such as virtual environments, project structuring, depedency tracking, and unit tests.

The following will be done from a Bash terminal on a machine running Linux. You will need to make changes to it for your specific OS.
_If you are running Windows I HIGHLY!! HIGHLY!! Recommend you at least install and setup [Windows Sub-system for Linux (WSL)](https://docs.microsoft.com/en-us/windows/wsl/install-win10)... or just switch to Linux :-)_

```bash
# in a directory you store all your different code projects
poetry new automatic_testing
cd automatic_testing
ls -lah
```

Notice that `poetry` will create a number of directories and some files. This folder structure is generally accepted to be a best practice in Python. More information on how to
use Poetry with an existing code base can be found on the Poetry website.

```bash
~/code-home/automatic_testing
├──automatic_testing
│  └──__init__.py
├──pyproject.toml
├──README.rst
└──tests
   ├──__init__.py
   └──test_automatic_testing.py
```

### Init Git Repository

Once our project is created we can go ahead and initialize our Git repository. I suggest adding a `.gitignore` starter files can be found [here](https://github.com/github/gitignore).

```bash
git init
git add .
```

### Add Python Code

Now that we have created the scafolding for our Python project and initilized the Git repo lets add some code. The following code is nothing
special, just something I threw together quickly in order to be an example for testing. Either create a file containing the code below or
feel free to use your own code.

```python
# located at ~/code-home/automatic_testing/automatic_testing/hello_world.py
import os
import datetime
import maya

def hello(user: str="World"):
    print(f"Hello {user}!")

def add(a: float, b: float) -> float:
    c = a + b
    return c

def mult(a: float, b: float) -> float:
    c = a * b
    return c

def div(a: float, b: float) -> float:
    c = a / b
    return c

def sub(a: float, b: float) -> float:
    c = a - b
    return c

def age(dob: str) -> int:
    dob = maya.when(dob)
    age = maya.MayaInterval(start=dob, end=maya.now())
    print("You were born ", maya.humanize.naturaltime(age.duration))
    return int(age.duration.split(" ")[0])

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser("Simple program to test Gitlab CI/CD")
    parser.add_argument('-u', '--user-name', action='append', help='This is the name that will be printed in the greeting')
    parser.add_argument('-a', '--A', type=float, help="A value to have something done to.")
    parser.add_argument('-b', '--B', type=float, help="B value to do something to A.")
    parser.add_argument('-f', '--function', dest='function', choices=['add', 'mult', 'div', 'sub'], help="The name of the function to run")
    parser.add_argument('-dob', dest='dob', type=str, help="Human formated date of birth")
    args = parser.parse_args()

    if args.user_name:
        hello(user=args.user_name[0])
    else:
        hello()

    if args.function:
        funcs = dict(add=add, mult=mult, div=div, sub=sub)
        print("Your answer is: ", funcs[args.function](a=args.A, b=args.B))

    if args.dob:
       age(args.dob)

```

### Add Test Code

Testing is critical to having good dependable code. Test driven design principles say that we should never write code unless we are writing it to pass a test case.
Realistically this might not always happen, but either way we need to have some tests setup so we know if our code is doing what we say it should be doing. Copy
the following code into your project or write your own tests. A good strategy for organizing your tests is to create one test file per normal file. I generally
keep all my tests stored in a `./tests/` directory and follow the pattern of `<real_code>.py` and `test_<real_code>.py`.

Pytest is my prefered method for testing in Python, but there are other ways and you don't even have to use a package, but it can make things simiplier. Again
for brevity sake this tutorial will not go into great detail on all the different features of pytest but rather just showcase some practical examples.

**Key Points**

- Only have to do `import pytest` in your test file.
- To test your code make an assertion that your code does what you say it should, and thats it.
- Snapshot testing is good for tracking how changes in code effect your data... just do `import snapshottest`.
- To run your tests using Poetry you can do `poetry run pytest` and it will run the tests and provide you with the results

_Options Reference_

- `-x` stops on first failure
- `-v -vv -vvv` various levels of verbousness
- `-k "<part of test name>"` run a specific test(s) aka Key word expression
- `-cov=<module to test> <tests>` get coverage report

```python
# located at ~/code-home/automatic_testing/tests/test_hello_world.py
import pytest
import snapshottest
from automatic_testing.hello_world import add, sub, mult, div, hello

def test_add(snapshot):
    t1 = dict(a=1, b=1, c=add(1,1))
    snapshot.assert_match(t1)

    t2 = dict(a=8, b=34, c=add(8,34))
    snapshot.assert_match(t2)

    assert add(1, 1) != 3

    assert add(40, 2) == 42

def test_mult(snapshot):

    t1 = dict(a=1, b=1, c=mult(1,1))
    snapshot.assert_match(t1)

    t2 = dict(a=8, b=34, c=mult(8,34))
    snapshot.assert_match(t2)

    assert mult(12, 1) != 13

    assert mult(5, 5) == [25](25)

```

### PyProject File

Just to make sure all dependecies are met for this project here is the `pyproject.toml` file I was using.

```toml
[tool.poetry]
name = "automatic_testing"
version = "0.1.0"
description = ""
authors = ["Matthew Camp <usmcamp0811@gmail.com>"]

[tool.poetry.dependencies]
python = "^3.6"
maya = "^0.6.1"

[tool.poetry.dev-dependencies]
pytest = "^5.2"
snapshottest = "^0.5.1"
pytest-cov = "^2.10.0"
pytest-flake8 = "^1.0.6"
pytest-bandit = "^0.5.2"
isort = "^5.0.4"
black = "^19.10b0"
pytest-black = "^0.3.10"
pytest-logger = "^0.5.1"
loguru = "^0.5.1"
coverage-badge = "^1.0.1"

[build-system]
requires = ["poetry>=0.12"]
build-backend = "poetry.masonry.api"
```

## Create Gitlab Runner Script

Gitlab will start a "Runner" whenever a repository has a `.gitlab-ci.yml` file present. You can think of the yaml file as kind of a cross between a Dockerfile and a docker-compose file (_If you don't know what either of those are then just think of it as a script that will create a virtual environment for your project_).
The file lets you instantiate a single docker container or a series of them to run your code. The computer resources used to run the container are either shared resources belonging to
Gitlab or you can create a Local Runner on your own hardware. Creating a Local Runner is outside the scope of this tutorial but this method would allow for test containers to have access
to large or senstive files.

### The Parts of the YAML File

- **Image:** The Docker Image you want Gitlab to run things on.
- **Stages:** List out the names of the stages you want Gitlab to run for you (ie. Build, Test, Deploy).
- **Before Script:** Any scripting that needs to be done to prep your environment ahead of time
- **Stage Section:**
  - **Build Definition:** All the steps that need to be done to build your project. _Not so important for Python... more relevant for a compiled language_
  - **Test Definition:** The steps required to run Pytest or any other testing your project requires.
  - **Deploy Definition:** You got here so your code is probably production ready..so lets push it to a Repository or what ever place is should go in order to be put into production.

**Minimal Example Yaml File**

```yaml
stages:
  - test

test:
  image: python:3.8
  stage: test
  script:
    - pip install poetry pip --upgrade
    - poetry install
    - poetry run pytest --cov=automatic_testing tests/
    - poetry run coverage-badge
  coverage: "/TOTAL.+ ([0-9]{1,3}%)/"
```

**More Advanced Example**
_NOTE: This is still a work in progress but it does work as it was adapted from an [issue](https://github.com/python-poetry/poetry/issues/366) on the Poetry GitHub_

```yaml
variables:
  PIP_CACHE_DIR: "${CI_PROJECT_DIR}/.cache/pip"

cache:
  key: "${CI_JOB_NAME}"
  paths:
    - .cache/pip
    - .venv

stages:
  - quality
  - tests

.install-deps-template: &install-deps
  before_script:
    - pip install poetry
    - poetry --version
    - poetry config virtualenvs.in-project true
    - poetry install -vv

.quality-template: &quality
  <<: *install-deps
  image: python:3.6
  stage: quality

.test-template: &test
  <<: *install-deps
  stage: tests
  coverage: "/TOTAL.+ ([0-9]{1,3}%)/"
  script:
    - poetry run pytest --cov=automatic_testing tests/
    - poetry run coverage-badge

  artifacts:
    paths:
      - tests/logs

    when: always
    expire_in: 1 week

# Quality jobs ----------------------

check-bandit:
  <<: *quality
  script: poetry run bandit .

check-black:
  <<: *quality
  script: poetry run black .

# check-flake8:
#   <<: *quality
#   script: poetry run flake8 ./automatic_testing

check-isort:
  <<: *quality
  script: poetry run isort .

# Tests jobs ------------------------

python3.6:
  <<: *test
  image: python:3.6

python3.7:
  <<: *test
  image: python:3.7

python3.8:
  <<: *test
  image: python:3.8
```

**Build a Docker Image Example**
_NOTE: This is also still under development but the basics are here_

```yaml
image: docker:19.03.1-dind

stages:
  - build_image
  - test

build_image:
  image: docker:latest
  stage: build_image
  script:
    # IMPORTANT!! For this to work you MUST! run `dockerd`
    - dockerd &
    - sleep 5
    - echo "Building"
    - docker build -t ci-cd-example .
    - docker login -u $CI_REGISTERY_USER -p $CI_REGISTERY_PASSWORD $CI_REGISTERY
    - docker push ci-cd-example
    - mkdir build
    - echo "Built example image" > build/example.txt
  artifacts:
    paths:
      - build/

test:
  stage: test
  script:
    - echo "Testing"
    - test -f "build/example.txt"
```

