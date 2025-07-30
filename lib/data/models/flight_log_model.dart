enum FlightLogType { notification, warning, error, success }

class FlightLog {
  final String id;
  final String name;
  final String description;
  final FlightLogType type;
  final DateTime time;

  FlightLog({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.time,
  });
}

final List<FlightLog> flightLogs = [
  FlightLog(
    id: '1',
    name: 'Flight Log 1',
    description: 'Flight Log 1 Description',
    type: FlightLogType.notification,
    time: DateTime.now(),
  ),
  FlightLog(
    id: '2',
    name: 'Flight Log 2',
    description: 'Flight Log 2 Description',
    type: FlightLogType.warning,
    time: DateTime.now(),
  ),
  FlightLog(
    id: '3',
    name: 'Flight Log 3',
    description: 'Flight Log 3 Description',
    type: FlightLogType.error,
    time: DateTime.now(),
  ),
  FlightLog(
    id: '4',
    name: 'Flight Log 4',
    description: 'Flight Log 4 Description',
    type: FlightLogType.success,
    time: DateTime.now(),
  ),
];
