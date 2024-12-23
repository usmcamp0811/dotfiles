import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import os
import argparse


def send_email(from_email, to_email, subject, body):
    # Gmail SMTP server configuration
    smtp_server = "smtp.gmail.com"
    smtp_port = 587

    # Get Gmail credentials from environment variables
    gmail_user = os.getenv("GMAIL_USER")
    gmail_password = os.getenv("GMAIL_PASSWORD")

    if not gmail_user or not gmail_password:
        print("Error: Gmail credentials are not set in environment variables.")
        print("GMAIL_USER")
        print("GMAIL_PASSWORD")
        return

    # Create the email
    msg = MIMEMultipart()
    msg["From"] = from_email
    msg["To"] = to_email
    msg["Subject"] = subject
    msg.attach(MIMEText(body, "plain"))

    try:
        # Connect to the SMTP server and send the email
        with smtplib.SMTP(smtp_server, smtp_port) as server:
            server.starttls()  # Secure the connection
            server.login(gmail_user, gmail_password)
            server.sendmail(gmail_user, to_email, msg.as_string())

        print("Email sent successfully.")
    except Exception as e:
        print(f"Failed to send email: {e}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Send an email using Gmail SMTP.")
    parser.add_argument(
        "--from_email", required=True, help="The sender's email address."
    )
    parser.add_argument(
        "--to_email", required=True, help="The recipient's email address."
    )
    parser.add_argument("--subject", required=True, help="The subject of the email.")
    parser.add_argument("--body", help="The body of the email as a string.")
    parser.add_argument(
        "--body_file", help="Path to a text file containing the body of the email."
    )

    args = parser.parse_args()

    if args.body:
        email_body = args.body
    elif args.body_file:
        try:
            with open(args.body_file, "r") as file:
                email_body = file.read()
        except Exception as e:
            print(f"Error reading body file: {e}")
            exit(1)
    else:
        print("Error: Either --body or --body_file must be provided.")
        exit(1)

    send_email(args.from_email, args.to_email, args.subject, email_body)
