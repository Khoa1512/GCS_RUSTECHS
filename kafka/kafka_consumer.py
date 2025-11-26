import json
import logging
import signal
import sys
from datetime import datetime

from confluent_kafka import Consumer, KafkaError, KafkaException


KAFKA_CONFIG_FILE = "client.properties"
KAFKA_TOPIC = 'gimbal-commands'

running = True

# Logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('./simple_consumer.log')
    ]
)
logger = logging.getLogger(__name__)

def signal_handler(sig, frame):
    """Handle Ctrl+C gracefully"""
    global running
    logger.info("🛑 Shutdown signal received")
    running = False
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

# ==================== KAFKA CONFIG ====================

def read_kafka_config(path=KAFKA_CONFIG_FILE):
    """Read Kafka configuration from properties file"""
    config = {}
    try:
        with open(path, 'r') as fh:
            for line in fh:
                line = line.strip()
                if line and not line.startswith("#"):
                    key, value = line.split('=', 1)
                    config[key.strip()] = value.strip()

        # Add consumer-specific settings
        config['group.id'] = 'gimbal-consumer-v2'
        config['auto.offset.reset'] = 'latest'
        config['enable.auto.commit'] = True

        logger.info(f"✅ Loaded Kafka config from {path}")
        return config
    except Exception as e:
        logger.error(f"❌ Failed to read Kafka config: {e}")
        sys.exit(1)

# ==================== KAFKA CONSUMER ====================

# Store latest message for external access
latest_message = None
message_callback = None

def set_message_callback(callback):
    global message_callback
    message_callback = callback
    logger.info("✅ Message callback registered")

def get_latest_message():

    return latest_message

def process_message(message):
    """Process and display Kafka message"""
    global latest_message

    try:
        # Parse JSON message
        data = json.loads(message.value().decode('utf-8'))

        # Store as latest message
        latest_message = data

        # Call callback if registered
        if message_callback:
            try:
                message_callback(data)
            except Exception as e:
                logger.error(f"❌ Callback error: {e}")

        # Display message
        print(json.dumps(data, indent=2))
        print("-" * 60)

    except json.JSONDecodeError as e:
        logger.error(f"❌ JSON decode error: {e}")
    except Exception as e:
        logger.error(f"❌ Process message error: {e}")

def consume_messages():
    """Main Kafka consumer loop"""
    try:
        # Load config from file
        config = read_kafka_config()

        # Create consumer
        consumer = Consumer(config)

        # Subscribe to topic
        consumer.subscribe([KAFKA_TOPIC])
        logger.info(f"✅ Subscribed to topic: {KAFKA_TOPIC}")

        logger.info("👂 Listening for messages...")
        logger.info("Press Ctrl+C to stop")
        logger.info("-" * 60)

        # Poll for messages
        while running:
            msg = consumer.poll(timeout=1.0)

            if msg is None:
                continue

            if msg.error():
                if msg.error().code() == KafkaError._PARTITION_EOF:
                    logger.debug(f"End of partition: {msg.topic()} [{msg.partition()}]")
                else:
                    logger.error(f"❌ Kafka error: {msg.error()}")
                continue

            # Process message
            process_message(msg)

    except KeyboardInterrupt:
        logger.info("🛑 Consumer interrupted")
    except KafkaException as e:
        logger.error(f"❌ Kafka exception: {e}")
    except Exception as e:
        logger.error(f"❌ Unexpected error: {e}")
    finally:
        consumer.close()
        logger.info("🔌 Kafka consumer closed")

# ==================== MAIN ====================

def main():
    """Main entry point"""
    logger.info(f"📋 Topic: {KAFKA_TOPIC}")
    logger.info("")

    consume_messages()

    logger.info("✅ Shutdown complete")

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        logger.info("🛑 Exiting...")
        sys.exit(0)
