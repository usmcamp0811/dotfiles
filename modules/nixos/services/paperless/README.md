---
type: NixOS Module
title: NixOS Paperless Module
description: The NixOS Paperless module facilitates the deployment and management of the Paperless document management system on your NixOS setup using a flake.
resource: ./default.nix
tags: [services, paperless]
---

# NixOS Paperless Module

## Overview

The NixOS Paperless module facilitates the deployment and management of the Paperless document management system on your NixOS setup using a flake. This module handles the necessary configurations and services required to run Paperless seamlessly. Paperless digitizes your documents and indexes them for quick access. PostgreSQL is used as the database for storing document metadata and other relevant information.

## Features

- **Easy Deployment**: Simplifies the deployment of Paperless with Nix flake configurations.
- **Database Configuration**: Sets up PostgreSQL as the database, and eases the configuration process.
- **Service Management**: Manages the necessary services like Gotenberg and Tika for document conversion and text extraction.

## Prerequisites

- NixOS installed on your machine.
- A running PostgreSQL instance.
- Basic knowledge of Nix flakes and configurations.

## Configuration

Below are the steps to integrate the Paperless module into your NixOS system configuration:

1. **Enable the Module**:

    ```nix
    campground.services.paperless.enable = true;
    ```

2. **Database Configuration**:

    Ensure PostgreSQL is enabled and configured with the required authentication:

    ```nix
    campground.services.postgresql = {
      enable = true;
      authentication = ''
        local paperless paperless  trust
        host  all  all  0.0.0.0/0  reject
        host  all  all  ::0/0  reject
      '';
      databases = [ 
        { 
          name = "paperless"; 
          user = "paperless"; 
        } 
      ];
    };
    ```

    It's preferable to use the username `paperless` and password `paperless` for setting up PostgreSQL.

3. **Service Configuration**:

    Set up other required configurations and services as per your requirements:

    ```nix
    services.paperless = {
      ...  // other configurations
    };
    ```

## Setup Process

1. After applying the configuration, the Paperless setup process will require you to set a username and password. It is preferable to use `paperless` as both the username and password especially when using PostgreSQL as your database.

2. Ensure that the PostgreSQL database and user `paperless` are properly created and configured before starting the Paperless service.

3. Access the Paperless web interface and complete the setup process by providing the necessary details.
