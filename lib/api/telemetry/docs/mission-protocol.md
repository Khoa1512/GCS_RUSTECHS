# Mission Protocol

Tài liệu này mô tả cách sử dụng DroneMAVLinkAPI để làm việc với MAVLink Mission Protocol: download, upload, clear, set-current và lấy Home (EKF origin).

## Tổng quan

- Hỗ trợ cả `MISSION_ITEM_INT` và legacy `MISSION_ITEM` để tương thích các flight stacks.
- Download theo kiểu tuần tự (sequential) để đảm bảo nhận đủ items (tránh tình trạng 5/5 chỉ về 3-4 items).
- Sự kiện (events) đầy đủ cho tiến trình download/upload và trạng thái mission hiện tại.
- Home position: hỗ trợ `HOME_POSITION` và `GPS_GLOBAL_ORIGIN`; có API để request chủ động.

## API chính

- `requestMissionList()`
- `requestMissionItem(int seq)`
- `startMissionUpload(List<PlanMissionItem> items)`
- `clearMission()`
- `setCurrentMissionItem(int seq)`
- `requestHomePosition()`

Các model/tiện ích:

- `MissionPlan.fromQgcPlanJson(String json)` và `toQgcPlanJson()`
- `MissionPlan.fromArduPilotWaypoints(String text)` và `toArduPilotWaypoints()`
- `PlanMissionItem` biểu diễn một mission item độc lập với wire format.

## Sự kiện liên quan

- `missionCount` (int)
- `missionItem` (PlanMissionItem)
- `missionDownloadProgress` ({received,total})
- `missionDownloadComplete`
- `missionUploadProgress` ({sent,total})
- `missionUploadComplete`
- `missionCurrent` ({seq,total,missionMode})
- `missionItemReached` (seq)
- `missionAck` (type)
- `missionCleared`
- `homePosition` ({lat,lon,alt,source})

## Download mission (sequential)

```dart
final api = DroneMAVLinkAPI();
int _total = 0;
int _next = 0;
final List<PlanMissionItem> items = [];

final sub = api.eventStream.listen((e) {
	switch (e.type) {
		case MAVLinkEventType.missionCount:
			_total = e.data as int;
			items.clear();
			_next = 0;
			if (_total > 0) api.requestMissionItem(_next++);
			break;
		case MAVLinkEventType.missionItem:
			final it = e.data as PlanMissionItem;
			while (items.length <= it.seq) {
				items.add(PlanMissionItem(seq: items.length, command: 0, frame: 0));
			}
			items[it.seq] = it;
			if (_next < _total) api.requestMissionItem(_next++);
			break;
		case MAVLinkEventType.missionDownloadComplete:
			print('Downloaded ${items.length}/$_total mission items');
			break;
		default:
			break;
	}
});

api.requestMissionList();
```

## Upload mission

```dart
Future<void> uploadFromText(DroneMAVLinkAPI api, String text) async {
	MissionPlan plan;
	if (text.trim().startsWith('{')) {
		plan = MissionPlan.fromQgcPlanJson(text);
	} else {
		plan = MissionPlan.fromArduPilotWaypoints(text);
	}
	api.startMissionUpload(plan.items);
}
```

Trong quá trình upload, autopilot có thể yêu cầu từng item qua `MissionRequestInt` hoặc `MissionRequest`. API xử lý và phản hồi tự động với định dạng phù hợp.

## Clear mission

```dart
api.clearMission();
// Lắng nghe MAVLinkEventType.missionCleared để xác nhận
```

## Set current item

```dart
api.setCurrentMissionItem(0); // đặt waypoint đầu tiên làm current
```

## Home Position (EKF origin)

```dart
// Yêu cầu chủ động
api.requestHomePosition();

// Lắng nghe khi có HOME_POSITION hoặc GPS_GLOBAL_ORIGIN
api.eventStream
	.where((e) => e.type == MAVLinkEventType.homePosition)
	.listen((e) {
		final home = e.data; // {lat, lon, alt, source}
		print('Home: ${home['lat']}, ${home['lon']}, alt=${home['alt']}m');
	});
```

## Ghi chú triển khai

- Download tuần tự giúp tránh mất item do out-of-order/overlap.
- Khi export `.plan`, `plannedHomePosition` sẽ dùng item đầu nếu là toạ độ toàn cục hợp lệ; nếu không, fallback về [0,0,0].
- Map/Route UI hiển thị marker Home từ EKF; nếu chưa có, dùng item đầu làm Home tạm và tránh trùng marker.
- `missionAck` và kết quả upload/download được phản ánh bằng các event progress/complete để cập nhật UI.
