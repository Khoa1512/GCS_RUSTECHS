#!/usr/bin/env python3

import json
import logging
from flask import Flask, request, jsonify
from flask_cors import CORS
from confluent_kafka import Producer
from datetime import datetime
import sys


# Flask HTTP Server
HTTP_HOST = "0.0.0.0"
HTTP_PORT = 8888  # Changed to avoid conflicts

# Kafka Configuration
KAFKA_CONFIG_FILE = "client.properties"
KAFKA_TOPIC_COMMAND = "gimbal-commands"


app = Flask(__name__)
CORS(app)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Kafka Producer
kafka_producer = None


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
        logger.info(f"✅ Loaded Kafka config from {path}")
        return config
    except Exception as e:
        logger.error(f"❌ Failed to read Kafka config: {e}")
        sys.exit(1)

def init_kafka_producer():
    """Initialize Kafka producer"""
    global kafka_producer

    try:
        config = read_kafka_config()
        kafka_producer = Producer(config)
        logger.info("✅ Kafka producer initialized")
        return True
    except Exception as e:
        logger.error(f"❌ Kafka producer init failed: {e}")
        return False

def publish_to_kafka(message):
    """Publish message to Kafka topic"""
    global kafka_producer

    if not kafka_producer:
        return False

    try:
        # Convert to JSON
        value = json.dumps(message)

        # Produce to Kafka
        kafka_producer.produce(
            KAFKA_TOPIC_COMMAND,
            key=message.get('action', 'unknown'),
            value=value.encode('utf-8')
        )

        # Flush to ensure delivery
        kafka_producer.flush()

        logger.info(f"📤 Published to Kafka: {message.get('action')}")
        return True
    except Exception as e:
        logger.error(f"❌ Kafka publish error: {e}")
        return False

# ==================== HTTP ENDPOINTS ====================

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'ok',
        'service': 'http-kafka-bridge',
        'kafka_connected': kafka_producer is not None
    })

@app.route('/gimbal/command', methods=['POST'])
def gimbal_command():
    """
    Receive gimbal command from Flutter and forward to Kafka

    Request Body (JSON):
    {
        "action": "lock",
        "mode": "lock",  // for velocity
        "pitch": 0,      // for velocity
        "yaw": 0,        // for velocity
        "x": 5000,       // for click_to_aim
        "y": 5000,       // for click_to_aim
        "show": true,    // for osd
        ...
    }
    """
    try:
        # Parse JSON from Flutter
        command = request.get_json()

        if not command or 'action' not in command:
            return jsonify({
                'success': False,
                'error': 'Invalid request: missing action'
            }), 400

        action = command.get('action')
        logger.info(f"📥 HTTP received: {action} from Flutter")

        # Forward to Kafka
        success = publish_to_kafka(command)

        if success:
            return jsonify({
                'success': True,
                'action': action,
                'message': 'Command forwarded to Kafka'
            })
        else:
            return jsonify({
                'success': False,
                'error': 'Failed to publish to Kafka'
            }), 500

    except Exception as e:
        logger.error(f"❌ Request error: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

def main():
    """Main entry point"""
    logger.info("=" * 60)
    logger.info("🌉 HTTP-Kafka Bridge for Gimbal Control")
    logger.info("=" * 60)
    logger.info("")
    logger.info(f"🌐 HTTP Server: http://{HTTP_HOST}:{HTTP_PORT}")
    logger.info(f"📋 Endpoint: POST /gimbal/command")
    logger.info("")
    logger.info(f"🎯 Kafka Config: {KAFKA_CONFIG_FILE}")
    logger.info(f"📋 Kafka Topic: {KAFKA_TOPIC_COMMAND}")
    logger.info("")

    # Initialize Kafka
    if not init_kafka_producer():
        logger.error("❌ Failed to initialize Kafka producer")
        sys.exit(1)

    # Start Flask server
    logger.info(f"👂 Listening on http://localhost:{HTTP_PORT}")
    logger.info("Press Ctrl+C to stop")
    logger.info("=" * 60)
    logger.info("")

    app.run(host=HTTP_HOST, port=HTTP_PORT, debug=False)

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        logger.info("")
        logger.info("🛑 Shutting down...")
        if kafka_producer:
            kafka_producer.flush()
        logger.info("✅ Bridge stopped cleanly")
    except Exception as e:
        logger.error(f"❌ Fatal error: {e}")
        sys.exit(1)

