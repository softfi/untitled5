
import 'dart:convert';

NearestGHospitalModel nearestGHospitalModelFromJson(String str) => NearestGHospitalModel.fromJson(json.decode(str));

String nearestGHospitalModelToJson(NearestGHospitalModel data) => json.encode(data.toJson());

class NearestGHospitalModel {
  NearestGHospitalModel({
    required this.data,
    required this.message,
  });

  List<MarkerList> data;
  String message;

  factory NearestGHospitalModel.fromJson(Map<String, dynamic> json) => NearestGHospitalModel(
    data: List<MarkerList>.from(json["data"].map((x) => MarkerList.fromJson(x))),
    message: json["message"],
  );

  Map<String, dynamic> toJson() => {
    "data": List<dynamic>.from(data.map((x) => x.toJson())),
    "message": message,
  };
}

class MarkerList {
  MarkerList({
    required this.id,
    required this.firstName,
    required this.displayName,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.isOnline,
    required this.isAvailable,
    required this.rating,
  });

  int id;
  String firstName;
  String displayName;
  String status;
  String latitude;
  String longitude;
  int isOnline;
  int isAvailable;
  int rating;

  factory MarkerList.fromJson(Map<String, dynamic> json) => MarkerList(
    id: json["id"],
    firstName: json["first_name"],
    displayName: json["display_name"],
    status: json["status"],
    latitude: json["latitude"],
    longitude: json["longitude"],
    isOnline: json["is_online"],
    isAvailable: json["is_available"],
    rating: json["rating"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "first_name": firstName,
    "display_name": displayName,
    "status": status,
    "latitude": latitude,
    "longitude": longitude,
    "is_online": isOnline,
    "is_available": isAvailable,
    "rating": rating,
  };
}
