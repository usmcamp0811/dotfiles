# Email Sender Script

This script is packaged as a Nix script and allows you to send an email using Gmail's SMTP server. It supports specifying the sender and recipient addresses, the email subject, and the email body either directly as a command-line argument or via a text file.

## Features

- Sends emails using Gmail's SMTP server.
- Allows dynamic configuration of sender, recipient, subject, and email body.
- Supports environment variables for secure Gmail credentials management.

## Usage

Run the script with the required arguments:

```bash
nix run gitlab:usmcamp0811/dotfiles#email-sender -- --from_email "sender@example.com" --to_email "recipient@example.com" \
--subject "Test Email" --body "This is the body of the email."
```

Alternatively, you can provide the email body through a text file:

```bash
nix run gitlab:usmcamp0811/dotfiles#email-sender -- --from_email "sender@example.com" --to_email "recipient@example.com" \
--subject "Test Email" --body_file "body.txt"
```

### Command-line Arguments

- `--from_email`: The sender's email address. (Required)
- `--to_email`: The recipient's email address. (Required)
- `--subject`: The subject of the email. (Required)
- `--body`: The body of the email as a string. (Optional, unless `--body_file` is provided)
- `--body_file`: Path to a text file containing the email body. (Optional, unless `--body` is provided)

### Example

Send an email with the body as a string:

```bash
nix run gitlab:usmcamp0811/dotfiles#email-sender -- --from_email "rebecca.clark@uscea.gov" --to_email "recipient@example.com" \
--subject "Official Notice" --body "This is a test email."
```

Send an email with the body from a file:

```bash
nix run gitlab:usmcamp0811/dotfiles#email-sender -- --from_email "rebecca.clark@uscea.gov" --to_email "recipient@example.com" \
--subject "Official Notice" --body_file "email_body.txt"
```

## Notes

- Ensure that the Gmail credentials are set in environment variables before running the script.
- Gmail enforces the authenticated sender's email address in the "From" header. Use a custom SMTP server for advanced use cases.
- This script is for educational purposes and should be used responsibly.

## Troubleshooting

- **Error: Gmail credentials are not set in environment variables.**

  - Ensure you have set the `GMAIL_USER` and `GMAIL_PASSWORD` environment variables correctly.

- **Failed to send email: [Error Details]**
  - Verify your credentials and ensure Gmail's "Allow less secure apps" is enabled or use an app-specific password.
