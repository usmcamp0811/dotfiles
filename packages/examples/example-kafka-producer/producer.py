import sys
from kafka import KafkaProducer

def send_message(producer, topic, message):
    producer.send(topic, message.encode())
    producer.flush()

def main():
    if len(sys.argv) not in [4, 5]:
        print("Usage: python script.py <host> <port> <topic> [message]")
        sys.exit(1)
    
    host = sys.argv[1]
    port = sys.argv[2]
    topic = sys.argv[3]
    server = f"{host}:{port}"

    producer = KafkaProducer(bootstrap_servers=[server])

    if len(sys.argv) == 5:
        # If message is provided as an argument, send it and exit
        message = sys.argv[4]
        send_message(producer, topic, message)
        print("Message Sent")
    else:
        # Interactive mode: repeatedly ask for messages to send
        try:
            while True:
                message = input("Enter message to send (Ctrl+C to stop): ")
                send_message(producer, topic, message)
        except KeyboardInterrupt:
            print("Exiting...")
        finally:
            producer.close()

if __name__ == "__main__":
    main()
