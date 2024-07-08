# Firefly III Plaid Connector 2 Setup Guide

## Introduction
This guide will walk you through setting up the Plaid Connector 2 for Firefly III, allowing you to link your financial accounts to Firefly III for easy transaction tracking.

## Prerequisites
- A Firefly III instance running.
- Basic knowledge of Docker and command-line operations.
- Plaid developer account.

## Steps to Setup Plaid Connector 2

### Step 1: Get a Plaid Developer Account
1. Visit the [Plaid website](https://plaid.com) and sign up for a developer account.
2. Complete the registration process.

### Step 2: Ensure You Have the Required Product
1. At a minimum, you need access to the Transactions product in Plaid. Ensure this is enabled in your Plaid account.

### Step 3: Fill Out the OAuth Linking Forms
1. Complete the [forms for OAuth linking](https://dashboard.plaid.com/settings/compliance/us-oauth-institutions) in your Plaid dashboard.
2. Note that this process may take a day or two for approval.

### Step 4: Run the Plaid Quickstart Docker Stack
1. Once your OAuth access is granted, clone the [Plaid Quickstart repository](https://github.com/plaid/quickstart).
2. Navigate to the cloned directory and run the Docker stack:
    ```bash
    docker-compose up
    ```

### Step 5: Sign Into Each of Your Institutions
1. Using the Quickstart app, sign into each of your financial institutions.
2. Obtain the two secrets provided for each account.

### Step 6: Get the Account ID for Each Account
1. For each institution, run the following command to retrieve the account ID:
    ```bash
    curl -X POST https://production.plaid.com/accounts/get \
    -H 'Content-Type: application/json' \
    -d '{
        "client_id": "yourclientid",
        "secret": "yoursecret",
        "access_token": "access-production-your-items-access-token"
    }'
    ```

### Step 7: Update the `application.yaml` File
1. Configure the `application.yaml` file with your specific settings. Below is an example configuration:

    ```yaml
    fireflyPlaidConnector2:
      syncMode: polled
      useNameForDestination: true
      timeZone: $TIMEZONE
      transferMatchWindowDays: 3
      polled:
        syncFrequencyMinutes: 10
        existingFireflyPullWindowDays: 5
        cursorFileDirectoryPath: persistence/
        allowItemToFail: false
      batch:
        maxSyncDays: 5
        setInitialBalance: true
      firefly:
        url: $FIREFLY_URL
        personalAccessToken: $FIREFLY_PERSONAL_ACCESS_TOKEN
      plaid:
        url: https://production.plaid.com
        clientId: $PLAID_CLIENT_ID
        secret: $PLAID_SECRET
        batchSize: 100
        maxRetries: 3
      categorization:
        primary:
          enable: true
          prefix: "plaid-primary-cat-"
        detailed:
          enable: true
          prefix: "plaid-detailed-cat-"
      accounts:
        - fireflyAccountId: $AMEX_FIREFLY_ACCOUT_ID
          plaidItemAccessToken: $AMEX_ACCESS_TOKEN
          plaidAccountId: $AMEX_ACCOUNT_ID
        - fireflyAccountId: $USAA_FIREFLY_CHECKING_ACCOUT_ID
          plaidItemAccessToken: $USAA_ACCESS_TOKEN
          plaidAccountId: $USAA_CHECKING_ACCOUNT_ID
        - fireflyAccountId: $USAA_FIREFLY_SAVING_ACCOUT_ID
          plaidItemAccessToken: $USAA_ACCESS_TOKEN
          plaidAccountId: $USAA_SAVINGS_ACCOUNT_ID
        - fireflyAccountId: $USAA_FIREFLY_SHARED_CHECKING_ACCOUT_ID
          plaidItemAccessToken: $USAA_ACCESS_TOKEN
          plaidAccountId: $USAA_SHARED_CHECKING_ACCOUNT_ID
      product:
        name: Firefly Plaid Connector 2
    logging:
      level:
        root: INFO
        net:
          djvk: DEBUG
    ```

### Conclusion
You should now have the Plaid Connector 2 set up for Firefly III. Ensure to check the logs and monitor the sync process for any issues.
