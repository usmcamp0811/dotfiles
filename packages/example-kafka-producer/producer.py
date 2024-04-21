import sys
from kafka import KafkaProducer

def send_message(producer, topic, message):
    producer.send(topic, message.encode())
    producer.flush()

def main():
    if len(sys.argv) != 4:
        print("Usage: python script.py <host> <port> <topic>")
        sys.exit(1)
    
    host = sys.argv[1]
    port = sys.argv[2]
    topic = sys.argv[3]
    server = f"{host}:{port}"

    producer = KafkaProducer(bootstrap_servers=[server])

    try:
        while True:
            message = input("Enter message to send (Ctr+C to stop): ")
            send_message(producer, topic, message)
    except KeyboardInterrupt:
        print("Exiting...")
    finally:
        producer.close()

if __name__ == "__main__":
    main()
