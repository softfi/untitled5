import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseService_Location {
  late SharedPreferences sharedPref;

  Future<Map<String, String>> writeLocationToFirebase(
      {required String driverEmail,
      required StreamSubscription<DatabaseEvent> streamController}) async {
    Map<String, String> res = {};
    await Firebase.initializeApp();
    DatabaseReference starCountRef =
        FirebaseDatabase.instance.ref(driverEmail.replaceAll(".", ""));
    streamController = starCountRef.onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value as Map;
      print("dfdffdfdfdfdfdfffd dfd $data");
      res = {"latitude": data["latitude"], "longitude": data["longitude"]};
    });
    // streamController.
    print(streamController.toString());
    return res;
  }
}
