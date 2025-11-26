# Gimbal WebSocket API v2.0

## 📋 Tổng Quan

WebSocket API cho điều khiển gimbal real-time với 8 chức năng core.

**Server:** `ws://0.0.0.0:8765`
**Gimbal:** `192.168.144.108:2332`

### Ưu Điểm

- ⚡ Nhanh hơn REST API 2-3 lần
- 🔄 Bidirectional communication
- 📉 Low overhead (không có HTTP headers)
- 🎯 Real-time control

---

## 🚀 Quick Start

### Cài Đặt

```bash
pip install websockets
```

### Khởi Động Server

```bash
# Mặc định: 0.0.0.0:8765
python api/gimbal_websocket.py

# Custom host/port
python api/gimbal_websocket.py --host 127.0.0.1 --port 9000
```

### Test Client

```bash
# Interactive mode
python api/test_websocket.py

# Run all tests
python api/test_websocket.py all

# Velocity test
python api/test_websocket.py velocity
```

---

## 📡 API Reference

### Message Format

**Request:**

```json
{
  "action": "command_name",
  "param": "value"
}
```

**Response:**

```json
{
  "action": "command_name",
  "success": true,
  "data": {...}
}
```

---

## 🎯 Core Functions (8)

### 1. get_status

Kiểm tra trạng thái kết nối gimbal.

```json
{ "action": "get_status" }
```

**Response:**

```json
{
  "action": "get_status",
  "success": true,
  "connected": true,
  "responding": true,
  "ip": "192.168.144.108",
  "port": 2332
}
```

### 2. get_data

Lấy sensor data (angles, velocities, zoom).

```json
{
  "action": "get_data",
  "timeout": 2.0
}
```

**Response:**

```json
{
  "action": "get_data",
  "success": true,
  "data": {
    "attitude": {
      "roll": 0.0,
      "pitch": -30.0,
      "yaw": 45.0
    },
    "angular_velocity": {
      "x": 0.0,
      "y": 0.0,
      "z": 0.0
    },
    "zoom": {
      "camera1": 1.0,
      "camera2": 1.0
    }
  }
}
```

### 3. lock

Enter Head Lock mode (gimbal lock orientation).

```json
{ "action": "lock" }
```

### 4. follow

Enter Head Follow mode (gimbal follows vehicle).

```json
{ "action": "follow" }
```

### 5. velocity

Control gimbal velocity (°/s) - requires lock/follow mode active.

```json
{
  "action": "velocity",
  "mode": "lock",
  "roll": 0,
  "pitch": -5.0,
  "yaw": 10.0
}
```

**Parameters:**

- `mode`: `"lock"` hoặc `"follow"`
- `roll`, `pitch`, `yaw`: Velocities in °/s

### 6. click_to_aim

Point gimbal at screen coordinates (0-10000).

```json
{
  "action": "click_to_aim",
  "x": 5000,
  "y": 3000
}
```

### 7. pip

Set Picture-in-Picture mode.

```json
{
  "action": "pip",
  "mode": 2
}
```

**Modes:** 0-4

### 8. osd

Toggle On-Screen Display.

```json
{
  "action": "osd",
  "show": true
}
```

---

## 🔌 Helper Functions

### connect

Connect to gimbal.

```json
{
  "action": "connect",
  "ip": "192.168.144.108",
  "port": 2332
}
```

### disconnect

Disconnect from gimbal.

```json
{ "action": "disconnect" }
```

---

## 💻 Code Examples

### Python Client

```python
import asyncio
import json
import websockets

async def control_gimbal():
    async with websockets.connect('ws://localhost:8765') as ws:
        # Receive welcome
        await ws.recv()

        # Connect to gimbal
        await ws.send(json.dumps({
            "action": "connect",
            "ip": "192.168.144.108",
            "port": 2332
        }))
        await ws.recv()

        # Enter Head Lock mode
        await ws.send(json.dumps({"action": "lock"}))
        await ws.recv()

        # Control yaw velocity
        await ws.send(json.dumps({
            "action": "velocity",
            "mode": "lock",
            "yaw": 10.0
        }))
        await ws.recv()

        # Stop
        await ws.send(json.dumps({
            "action": "velocity",
            "mode": "lock",
            "yaw": 0
        }))
        await ws.recv()

asyncio.run(control_gimbal())
```

### JavaScript (Browser)

```javascript
const ws = new WebSocket("ws://localhost:8765");

ws.onopen = () => {
  console.log("Connected");

  // Connect to gimbal
  ws.send(
    JSON.stringify({
      action: "connect",
      ip: "192.168.144.108",
      port: 2332,
    })
  );
};

ws.onmessage = (event) => {
  const response = JSON.parse(event.data);
  console.log("Response:", response);
};

// Control gimbal
function aimAtTarget(x, y) {
  ws.send(
    JSON.stringify({
      action: "click_to_aim",
      x: x,
      y: y,
    })
  );
}

// Usage
aimAtTarget(5000, 3000);
```

---

## 🧪 Testing Commands

### Interactive Mode

```bash
python api/test_websocket.py
```

**Available commands:**

- `connect` - Connect to gimbal
- `status` - Get connection status
- `data` - Get gimbal sensor data
- `lock` - Enter Head Lock mode
- `follow` - Enter Head Follow mode
- `v <p> <y>` - Velocity control (pitch, yaw)
- `aim <x> <y>` - Click to aim
- `pip <mode>` - PIP mode (0-4)
- `osd <on|off>` - Toggle OSD
- `disconnect` - Disconnect
- `q` - Quit

---

## ⚡ Performance

WebSocket nhanh hơn REST API ~2-3x:

| Metric         | REST API | WebSocket |
| -------------- | -------- | --------- |
| Single command | ~50ms    | ~20ms     |
| 20 commands    | ~1000ms  | ~300ms    |
| Overhead       | High     | Low       |

---

## 🔧 Best Practices

1. **Keep connection alive** - Không connect/disconnect liên tục
2. **Check `success` field** - Luôn kiểm tra response
3. **Enter mode before velocity** - Lock/Follow mode required
4. **Stop motion** - Send velocity=0 để dừng
5. **Handle errors** - Xử lý exception và retry logic

---

## ❓ Troubleshooting

### Connection refused

- Kiểm tra server: `python api/gimbal_websocket.py`
- Kiểm tra port: default `8765`

### Gimbal not responding

- Kiểm tra network: gimbal phải ở `192.168.144.108:2332`
- Test connection: `{"action": "get_status"}`

### Commands fail

- Phải connect trước: `{"action": "connect"}`
- Kiểm tra `success` field trong response

---

## 📝 Changelog

**v2.0** (Current)

- 8 core functions + 2 helpers
- WebSocket protocol
- Performance tối ưu
- Real-time bidirectional communication
