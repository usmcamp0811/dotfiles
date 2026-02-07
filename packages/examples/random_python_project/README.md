# Random Python Project

This is a simple Python project that calculates the number of days between two given dates.

## Prerequisites

- Nix (for reproducible environments)
- Docker (for containerized execution)

## Usage

### Building the Docker Container

1. Build the Docker image:
   ```sh
   nix build gitlab:/initech-project/main-codebase#random_python_project.container
   docker load -i ./result
   ```

### Running the Application

To run the application with Nix:

```sh
nix run gitlab:/initech-project/main-codebase#random_python_project -- <date1> <date2>
```

To run the application with the built Docker container:

```sh
docker run -it --rm random_python:latest <date1> <date2>
```

Example:

```sh
docker run -it --rm random_python:latest 10-12-1934 10-3-1945
```

### Running Tests

To run the tests using Nix:

```sh
nix run .#random_python_project.test
```

## Project Structure

```
random_python_project/
├── docs/                   # Documentation files
├── random_python_project/  # Source code
│   ├── __init__.py
│   └── random_python_project.py
├── tests/                  # Test files
│   └── test_random_python_project.py
├── .gitignore
├── .gitlab-ci.yml
├── default.nix
├── poetry.lock
├── pyproject.toml
└── README.md
```
