import 'package:skylink/core/constant/app_image.dart';
import 'package:skylink/data/models/drone_information_mode.dart';
import 'package:skylink/data/models/flight_information_model.dart';

class FakeData {
  static List<DroneInformationModel> droneInformation = [
    DroneInformationModel(
      name: 'Rustech Vtol',
      image: AppImage.vtol,
      description: 'Rustech first ever Vtol drone',
      price: '100',
    ),
  ];

  static List<FlightInformationModel> fightInformation = [
    FlightInformationModel(
      speed: '100',
      height: '100',
      weight: '100',
      battery: '100',
      flightTime: '100',
      iso: '100',
      resolution: '100',
      fps: '100',
      shutter: '100',
    ),
  ];
}
