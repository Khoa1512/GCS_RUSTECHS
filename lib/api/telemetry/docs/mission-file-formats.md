# Mission File Formats

API hỗ trợ hai định dạng mission phổ biến để import/export: QGC .plan (JSON) và QGC WPL 110 (plain text).

## QGC .plan (JSON)

- Sử dụng: `MissionPlan.fromQgcPlanJson(String json)` và `String toQgcPlanJson()`.
- Khi export, `plannedHomePosition` sẽ được suy luận từ item đầu nếu item có toạ độ toàn cục (lat/lon) hợp lệ; nếu không, fallback [0,0,0].
- Trường thường gặp trong phần mission (tối giản hoá theo nhu cầu):
	- `mission.items[]`: danh sách waypoint/command
		- `command`: MAV_CMD (int)
		- `frame`: MAV_FRAME (int)
		- `params`: [p1, p2, p3, p4]
		- `coordinate`: [lat, lon, alt] (khi là frame toàn cục)
		- `autoContinue`: bool
		- `doJumpId` (hoặc `seq` nội bộ): thứ tự item

Ghi chú: Cấu trúc đầy đủ của QGC .plan có thêm metadata, firmware type, geoFence, rallyPoints… API tập trung vào phần mission core để tương thích upload/download.

## QGC WPL 110 (Plain Text)

- Sử dụng: `MissionPlan.fromArduPilotWaypoints(String text)` và `String toArduPilotWaypoints()`.
- Dòng đầu tiên là header: `QGC WPL 110`.
- Mỗi dòng dữ liệu là 12 cột, tab-separated:

```text
INDEX  CURRENT  FRAME  COMMAND  P1  P2  P3  P4  X/LAT  Y/LON  Z/ALT  AUTOCONTINUE
```

Trong đó:

- INDEX: thứ tự item (0-based)
- CURRENT: 1 nếu là current waypoint, ngược lại 0
- FRAME: MAV_FRAME (0: GLOBAL, 3: GLOBAL_RELATIVE_ALT, …)
- COMMAND: MAV_CMD (ví dụ 16: NAV_WAYPOINT)
- P1..P4: params
- X/LAT, Y/LON, Z/ALT: toạ độ và độ cao
- AUTOCONTINUE: 1 hoặc 0

### Ví dụ

```text
QGC WPL 110
0  1  0  16  0.149999999999999994  0  0  0  8.54800000000000004  47.3759999999999977  550  1
1  0  0  16  0.149999999999999994  0  0  0  8.54800000000000004  47.3759999999999977  550  1
2  0  0  16  0.149999999999999994  0  0  0  8.54800000000000004  47.3759999999999977  550  1
```

### Lưu ý tương thích

- Một số autopilot sẽ yêu cầu legacy `MISSION_ITEM` thay vì `MISSION_ITEM_INT` khi upload; API tự động đáp ứng dạng float nếu cần.
- Khi đọc WPL, các giá trị số nguyên lớn có thể bị format với nhiều chữ số thập phân; hàm import của API xử lý và quy đổi về kiểu số phù hợp.
- Chú ý FRAME phù hợp với COMMAND để đảm bảo hành vi bay đúng mong đợi.
