#!/usr/bin/env python3
"""
Test - Import kafka_consumer để nhận JSON data real-time
Chỉ cần import và đăng ký callback, sẽ tự động nhận message mới
"""

import kafka_consumer
import threading

# Biến để lưu data mới nhất (nếu cần)
current_data = None

def handle_message(data):
    """
    Callback - Tự động được gọi khi có message mới từ Kafka
    Real-time, không cần polling!
    """
    global current_data
    current_data = data

    # Xử lý data ngay khi nhận được
    action = data.get('action')
    print(f"\n✅ Received: {action}")

    if action == 'velocity':
        print(f"   Pitch: {data.get('pitch')}, Yaw: {data.get('yaw')}")
    elif action == 'lock':
        print(f"   🔒 Locked")
    elif action == 'follow':
        print(f"   🎯 Following")


kafka_consumer.set_message_callback(handle_message)

print("⌨️  Press Ctrl+C to stop\n")

# Chạy consumer trong background thread
consumer_thread = threading.Thread(target=kafka_consumer.main, daemon=True)
consumer_thread.start()

# Main thread có thể làm việc khác
try:
    import time
    while True:
        time.sleep(1)
        # Làm việc khác ở đây...
        # current_data luôn là message mới nhất

except KeyboardInterrupt:
    print("\n🛑 Stopped")
