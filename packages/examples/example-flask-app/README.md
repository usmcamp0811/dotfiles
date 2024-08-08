# Simple Flask App with Nix and uWSGI

## Overview

This repository provides a template for deploying a Flask application using Nix and uWSGI. It's designed for Python developers familiar with Flask but new to Nix.

## Prerequisites

- Nix package manager
- Basic understanding of Flask

## How it Works

### Nix Package

The `default.nix` file defines a Nix package for the Flask application. It specifies all the dependencies and configurations needed to run the app.

- `uwsgiWithPython3`: uWSGI server with Python 3 plugin.
- `pythonWithFlask`: Python environment with Flask installed.
- `example-flask-app`: The Flask app itself.

### uWSGI

uWSGI is used to serve the Flask application. It is a WSGI server that communicates with web servers like Nginx and serves Python applications. The `uwsgi.ini` file contains uWSGI configurations such as:

- Socket to bind to: `:8081`
- HTTP access: `:8080`
- Number of processes: `4`
- Number of threads: `2`

This setup allows you to access the application both via a socket and HTTP, providing flexibility for different deployment scenarios.

### Dev Shell

A development shell is provided with various Nix utilities and the Flask app as build inputs. The `shellHook` script prints a welcome message and provides two commands:

- `run-flask-app`: Starts the Flask app using uWSGI.
- `dev-flask-app`: Runs the Flask development server.

## Getting Started

1. Navigate to the `./packages` directory.
2. Create a new directory with the name of your Flask app.
3. Inside this new directory, create a `default.nix` file similar to the one provided, but customized for your app.

### Modifying the Dev Shell

1. Navifate to the `./shells` directory.
2. Create a new directory with the name of your Flask app.
3. Inside this new directory, create a `default.nix` file that looks like the below.

```nix
{ mkShell
, pkgs
, ...
}:
mkShell {
  buildInputs = with pkgs; [
    deadnix
    hydra-check
    nix-diff
    nix-index
    nix-prefetch-git
    nixpkgs-fmt
    nixpkgs-hammering
    nixpkgs-lint
    snowfallorg.flake
    statix
    campground.<your-flask-app-name> # same as ./packages/<your-flask-app-name>
  ];

shellHook = ''
  echo -e "\e[32m+-----------------------------------------------------------+\e[0m"
  echo -e "\e[32m|🏕️  Welcome to the Campground                              |\e[0m"
  echo -e "\e[32m+-----------------------------------------------------------+\e[0m"
  echo -e "\e[34m| run-flask-app  \e[0m - \e[37mTo start Flask with uWSGI               |\e[0m"
  echo -e "\e[34m| dev-flask-app  \e[0m - \e[37mTo run the Flask dev server.            |\e[0m"
  echo -e "\e[32m+-----------------------------------------------------------+\e[0m"

  # Additional setup can go here
'';
}
```

## Example Directory Structure

```
./packages/
└── your-flask-app/
    └── default.nix
```
