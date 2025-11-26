# Kafka Consumer - Hướng dẫn sử dụng đơn giản

## 🎯 Cách sử dụng

### Bước 1: Import module

```python
import kafka_consumer
```

### Bước 2: Đăng ký callback

```python
def my_callback(data):
    """Tự động được gọi khi có message mới"""
    action = data.get('action')
    print(f"New message: {action}")

    # Xử lý data ở đây
    if action == 'velocity':
        pitch = data.get('pitch')
        yaw = data.get('yaw')
        # Làm gì đó với pitch, yaw...

# Đăng ký callback
kafka_consumer.set_message_callback(my_callback)
```

### Bước 3: Chạy consumer

```python
# Chạy trong background thread
import threading
consumer_thread = threading.Thread(
    target=kafka_consumer.main,
    daemon=True
)
consumer_thread.start()

# Code của bạn tiếp tục chạy
while True:
    # Làm việc khác...
    pass
```

---

## ✨ Ưu điểm

✅ **Real-time** - Callback tự động được gọi ngay khi có message
✅ **Không cần polling** - Không cần check liên tục
✅ **Đơn giản** - Chỉ cần import và đăng ký callback
✅ **Luôn mới nhất** - Message luôn được cập nhật real-time

---

## 📝 Ví dụ hoàn chỉnh

```python
import kafka_consumer
import threading

def handle_message(data):
    action = data.get('action')
    print(f"Received: {action}")

# Đăng ký callback
kafka_consumer.set_message_callback(handle_message)

# Chạy consumer trong background
consumer_thread = threading.Thread(
    target=kafka_consumer.main,
    daemon=True
)
consumer_thread.start()

# Main code
while True:
    # Làm việc khác...
    pass
```

---

## 🧪 Test

```bash
python3 test_consumer.py
```

---

## 💡 Lưu ý

- Callback được gọi **TỰ ĐỘNG** mỗi khi có message mới
- **Không cần** chạy `kafka_consumer.py` riêng
- Chỉ cần **import** và **đăng ký callback**
- Message luôn **real-time**, không delay
