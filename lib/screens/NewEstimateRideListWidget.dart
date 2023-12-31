import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_map_polyline_new/google_map_polyline_new.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mqtt_client/mqtt_client.dart';

import '../../components/CouPonWidget.dart';
import '../../components/RideAcceptWidget.dart';
import '../../main.dart';
import '../../network/RestApis.dart';
import '../../utils/Colors.dart';
import '../../utils/Common.dart';
import '../../utils/Constants.dart';
import '../../utils/Extensions/AppButtonWidget.dart';
import '../../utils/Extensions/app_common.dart';
import '../../utils/Extensions/app_textfield.dart';
import '../components/BookingWidget.dart';
import '../components/CarDetailWidget.dart';
import '../model/CurrentRequestModel.dart';
import '../model/EstimatePriceModel.dart';
import '../model/distanceModel.dart';
import '../screens/ReviewScreen.dart';
import '../utils/Extensions/ConformationDialog.dart';
import '../utils/Extensions/StringExtensions.dart';
import '../utils/images.dart';
import 'RiderDashBoardScreen.dart';
import 'package:http/http.dart' show get;
import 'dart:ui' as ui;

Driver? DRIVER_DATA_BY_ALOK;

class NewEstimateRideListWidget extends StatefulWidget {
  final LatLng sourceLatLog;
  final LatLng destinationLatLog;
  final String sourceTitle;
  final String destinationTitle;
  bool isCurrentRequest;
  final int? servicesId;
  final int? id;

  NewEstimateRideListWidget({
    required this.sourceLatLog,
    required this.destinationLatLog,
    required this.sourceTitle,
    required this.destinationTitle,
    this.isCurrentRequest = false,
    this.servicesId,
    this.id,
  });

  @override
  NewEstimateRideListWidgetState createState() =>
      NewEstimateRideListWidgetState();
}

class NewEstimateRideListWidgetState extends State<NewEstimateRideListWidget> {
  Completer<GoogleMapController> _controller = Completer();
  final Set<Marker> markers = {};
  Set<Polyline> _polyLines = Set<Polyline>();

  late PolylinePoints polylinePoints;
  late Marker sourceMarker;
  late Marker destinationMarker;
  late LatLng userLatLong;
  late DateTime scheduleData;

  TextEditingController promoCode = TextEditingController();
  TextEditingController nameController = TextEditingController();
  TextEditingController phoneController = TextEditingController();

  bool isBooking = false;
  bool isRideSelection = false;
  bool isOther = true;

  int selectedIndex = 0;
  int rideRequestId = 0;
  int mTotalAmount = 0;

  String? mSelectServiceAmount;

  List<String> cashList = ['cash', 'wallet'];
  List<ServicesListData> serviceList = [];
  List<LatLng> polylineCoordinates = [];

  late BitmapDescriptor sourceIcon;
  late BitmapDescriptor destinationIcon;
  late BitmapDescriptor driverIcon;

  LatLng? driverLatitudeLocation;

  String paymentMethodType = '';

  ServicesListData? servicesListData;
  OnRideRequest? rideRequest;
  Driver? driverData;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    sourceIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: 2.5), SourceIcon);
    destinationIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: 2.5), DestinationIcon);
    driverIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: 2.5), DriverIcon);
    getServiceList();
    getCurrentRequest();
    mqttForUser();
    if (!widget.isCurrentRequest) getNewService();
    isBooking = widget.isCurrentRequest;
    getWalletData().then((value) {
      mTotalAmount = value.totalAmount!;
    });
  }

  Future<void> getCurrentRequest() async {
    await getCurrentRideRequest().then((value) {
      if (value.rideRequest != null || value.onRideRequest != null) {
        rideRequest = value.rideRequest ?? value.onRideRequest;
      }
      if (value.driver != null) {
        driverData = value.driver!;
        DRIVER_DATA_BY_ALOK=driverData;
      } else {}

      if (rideRequest != null) {
        //getUserDetailLocation();
        setState(() {});
        if (driverData != null) {
          //start the tracking stream here
          // var tes=driverData.
          testFn(driverId: driverData!.email!);
          if (timer != null) {
            timer?.cancel();
          }
          timer = Timer.periodic(
              Duration(seconds: 20), (Timer t) => getUserDetailLocation());
        }
      }
      if (rideRequest!.status == COMPLETED &&
          rideRequest != null &&
          driverData != null) {
        print(
            "dsfsdf fsdgsgdgs dgsg r324rdsfs dgsdgfwertwe gdsgdg ========> this flow change a/c to client");
        launchScreen(context,
            ReviewScreen(rideRequest: rideRequest!, driverData: driverData),
            pageRouteAnimation: PageRouteAnimation.SlideBottomTop,
            isNewTask: true);
      }
    }).catchError((error) {
      log(error.toString());
    });
    Future.delayed(Duration(seconds: 10), () {
      print("ghusgya");
      getCurrentRequest();
      mqttForUser();
    });
  }

  LatLng? alokLatLon;
  Set<Marker> alokMarkerSet = Set();
  var alokMarkerList = [];
  Set<Polyline> alok_polyline = {};
  Set<Polyline> newTestPolyline = {};
  List<Polyline>? testList;
  double zoomLevel = 13;
  double bearing = 13;
  double tilt = 13;
  GoogleMapPolyline googleMapPolyline =
  new GoogleMapPolyline(apiKey: "AIzaSyCJBGAgBHOCkFIpPtcLHgXWgowMF1iCQ7E");


  DistanceModelClass? distanceModelClass;

  void getTime(
      {required double startLat, required double endLat, required double startLong, required double endLong}) {
    print(
        " this the full alt long send to the google for the time Api request            https://maps.googleapis.com/maps/api/distancematrix/json?units=imperial&origins=$startLat,$startLong&destinations=$endLat,$endLong&key=AIzaSyCm58QHiWeoDd1NYp7M9g0WpZ8dogkKvBo");
    Future.delayed(Duration(seconds: 2)).then((value) {
      Uri uri = Uri.parse(
          'https://maps.googleapis.com/maps/api/distancematrix/json?units=imperial&origins=$startLat,$startLong&destinations=$endLat,$endLong&key=AIzaSyCJBGAgBHOCkFIpPtcLHgXWgowMF1iCQ7E');
      get(uri).then((value) {
        print("this is the result from the google matrix api ${value.body}");
        var data = jsonDecode(value.body);
        distanceModelClass = DistanceModelClass.fromJson(data);
        setState(() {});
        print("klsfds kfsndfj sfbs hsdf h h ${distanceModelClass?.rows[0]
            .elements[0].duration.text}");
        /*try {
          print(data[0]["rows"]['elements']['duration']['text']+"this is the required time taken by the driver");
        } on Exception catch (e) {
          print(data[0].rows[0].elements[0].duration.text+"this is the required time taken by the driver");
        }*/
      });
    });
  }


  bool isLocked = true;
  Timer? myTimer;

  setLock() {
    if (myTimer == null) {
      myTimer = Timer.periodic(Duration(seconds: 2), (timer) {
        setState(() {
          isLocked = !isLocked;
        });
      });
    };
  }

  Future<LatLng> getUserCurrentLocation() async {
    Position value = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    return LatLng(value.latitude, value.longitude);
  }


  Future<Uint8List> getImages(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(), targetHeight: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List();
  }


  void testFn({required String driverId}) async {
    print("this is fewgrw er emailo $driverId");
    Map<String, String> res = {};
    await Firebase.initializeApp();
    DatabaseReference starCountRef =
    FirebaseDatabase.instance.ref(driverId.replaceAll(".", ""));
    starCountRef.onValue.listen((DatabaseEvent event) async {
      if (!isLocked) {
        newTestPolyline = <Polyline>[].toSet();
        alok_polyline.clear();
        final data = event.snapshot.value as Map;
        print("=====>>>>>09090009n 2ue229 9 $data");
        res = {"latitude": data["latitude"], "longitude": data["longitude"]};

        getTime(startLat: widget.sourceLatLog.latitude,
            endLat: double.parse(data["latitude"]),
            startLong: widget.sourceLatLog.longitude,
            endLong: double.parse(data["longitude"]));


        // newTestPolyline.clear();
        // newTestPolyline.add();

        final Uint8List markIcons = await getImages('images/ic_car.png', 100);
        alokMarkerList.clear();
        alokMarkerList.add({
          "id": "loc1",
          "marker": Marker(
            icon: BitmapDescriptor.fromBytes(markIcons),

            markerId: MarkerId(LatLng(double.parse(data["latitude"].toString()),
                double.parse(data["longitude"].toString()))
                .toString()),
            position: LatLng(double.parse(data["latitude"].toString()),
                double.parse(data["longitude"].toString())),
          )
        });
        alokLatLon = LatLng(double.parse(data["latitude"].toString()),
            double.parse(data["longitude"].toString()));

        try {
          final GoogleMapController controller = await _controller.future;
          await controller.moveCamera(
              CameraUpdate.newCameraPosition(CameraPosition(
                  target: alokLatLon!,
                  zoom: zoomLevel,
                  bearing: bearing,
                  tilt: tilt)));
        } catch (e) {}
//zoom here

        alokMarkerSet = {};
        for (var i = 0; i < alokMarkerList.length; i++) {
          alokMarkerSet.add(alokMarkerList[i]["marker"]);
        }

        setState(() {
          alok_polyline.clear();
        });
        if (rideRequest != null &&
            (rideRequest!.status == ACCEPTED ||
                rideRequest!.status == ARRIVING ||
                rideRequest!.status == ARRIVED)) {
          List<LatLng>? listOfLatLong = await googleMapPolyline
              .getCoordinatesWithLocation(
            origin: rideRequest!.status == ARRIVED
                ? await getUserCurrentLocation()
                : widget.sourceLatLog,
            destination: rideRequest!.status == ARRIVED ? widget
                .destinationLatLog : LatLng(
                double.parse(data["latitude"].toString()),
                double.parse(data["longitude"].toString())),
            mode: RouteMode.transit,)
              .then((value) {
            if (value!.isNotEmpty) {
              debugPrint("this is the lst of polyline ${List.generate(
                  value.length, (index) => "${value[index]
                  .latitude},${value[index].longitude}")}");
              newTestPolyline.clear();
              newTestPolyline.add(Polyline(
                  polylineId: PolylineId(value[0].latitude.toString()),
                  color: Colors.blueAccent,
                  // color:Colors.primaries[Random().nextInt(Colors.primaries.length)],
                  width: 5,
                  visible: true,
                  points: List.generate(
                      value.length, (index) => value[index])));


              alok_polyline.clear();
              //aaaaaaaaaaaaaa
              /* alok_polyline.add(Polyline(
                polylineId: PolylineId(value[0].latitude.toString()),
                color:
                    Colors.primaries[Random().nextInt(Colors.primaries.length)],
                width: 10,
                visible: true,
                points: List.generate(value.length, (index) => value[index])));*/
              alok_polyline.add(Polyline(
                  polylineId: PolylineId(value[0].latitude.toString()),
                  color: Colors.blueAccent,
                  // color:Colors.primaries[Random().nextInt(Colors.primaries.length)],
                  width: 5,
                  visible: true,
                  points: List.generate(
                      value.length, (index) => value[index])));
              setState(() {});
            }
          });
          print(
              "this is the lat long list data data if fffffffff $listOfLatLong");
          print("this is the lat long list ${widget.sourceLatLog}");
          print(
              "this is the lat long list ${LatLng(
                  double.parse(data["latitude"].toString()),
                  double.parse(data["longitude"].toString()))}");
        } else {
          List<LatLng>? listOfLatLong = await googleMapPolyline
              .getCoordinatesWithLocation(
              origin: widget.destinationLatLog,
              destination: LatLng(double.parse(data["latitude"].toString()),
                  double.parse(data["longitude"].toString())),
              mode: RouteMode.driving)
              .then((value) {
            if (value!.isNotEmpty) {
              alok_polyline.clear();
              //aaaaaaaaaaaaaa
              alok_polyline.add(Polyline(
                  polylineId: PolylineId(value[0].latitude.toString()),
                  color: Colors
                      .blueAccent /*Colors.primaries[Random().nextInt(Colors.primaries.length)]*/,
                  width: 10,
                  visible: true,
                  points: List.generate(
                      value.length, (index) => value[index])));
            }
          });
          print(
              "this is the lat long list data data eeeeeeeeee  $listOfLatLong");
          print("this is the lat long list ${widget.destinationLatLog}");
          print(
              "this is the lat long list ${LatLng(
                  double.parse(data["latitude"].toString()),
                  double.parse(data["longitude"].toString()))}");
        }

        /*alok_polyline.add(Polyline(polylineId: const PolylineId("value"),
          color: Colors.pink,
          width: 10,
          visible: true,
          points:[widget.sourceLatLog,LatLng(double.parse(data["latitude"].toString()),
              double.parse(data["longitude"].toString()))])
      );*/

        setState(() {
          alokLatLon = LatLng(double.parse(data["latitude"].toString()),
              double.parse(data["longitude"].toString()));
        });

        ///_polyLines.clear();
        ///polylineCoordinates.clear();


        var result = await polylinePoints.getRouteBetweenCoordinates(
          googleMapAPIKey,
          PointLatLng(
              LatLng(
                  widget.sourceLatLog.latitude, widget.sourceLatLog.longitude)
                  .latitude,
              LatLng(
                  widget.sourceLatLog.latitude, widget.sourceLatLog.longitude)
                  .longitude),
          rideRequest != null &&
              (rideRequest!.status == ACCEPTED ||
                  rideRequest!.status == ARRIVING ||
                  rideRequest!.status == ARRIVED)
              ? PointLatLng(double.parse(data["latitude"].toString()),
              double.parse(data["longitude"].toString()))
              : PointLatLng(
              LatLng(widget.destinationLatLog.latitude,
                  widget.destinationLatLog.longitude)
                  .latitude,
              LatLng(widget.destinationLatLog.latitude,
                  widget.destinationLatLog.longitude)
                  .longitude),
        );
        if (result.points.isNotEmpty) {
          /*result.points.forEach((element) {
          polylineCoordinates.add(LatLng(element.latitude, element.longitude));
        });*/
        }
        /*   setState(() {
        _polyLines.add(Polyline(
          visible: true,
          width: 5,
          polylineId: PolylineId('poly'),
          color: Color.fromARGB(255, 40, 122, 198),
          points: polylineCoordinates,
        ));
      });*/
        setState(() {});
      } else {
        setLock();
      }
    });
  }

  Future<void> getServiceList() async {
    markers.clear();
    polylinePoints = PolylinePoints();

    ///commented by dharmendra at 6th sep 2023 for remove two plyline
    setPolyLines(
      sourceLocation:
      LatLng(widget.sourceLatLog.latitude, widget.sourceLatLog.longitude),
      destinationLocation: LatLng(widget.destinationLatLog.latitude,
          widget.destinationLatLog.longitude),
      driverLocation: driverLatitudeLocation,
    );
    MarkerId id = MarkerId('Source');
    markers.add(
      Marker(
        markerId: id,
        position:
        LatLng(widget.sourceLatLog.latitude, widget.sourceLatLog.longitude),
        infoWindow: InfoWindow(title: widget.sourceTitle),
        icon: sourceIcon,
      ),
    );
    MarkerId id2 = MarkerId('DriverLocation');
    markers.remove(id2);

    MarkerId id3 = MarkerId('Destination');
    markers.remove(id3);
    rideRequest != null &&
        (rideRequest!.status == ACCEPTED ||
            rideRequest!.status == ARRIVING ||
            rideRequest!.status == ARRIVED)
        ? markers.add(
      Marker(
        markerId: id2,
        position: driverLatitudeLocation!,
        icon: driverIcon,
      ),
    )
        : markers.add(
      Marker(
        markerId: id3,
        position: LatLng(widget.destinationLatLog.latitude,
            widget.destinationLatLog.longitude),
        infoWindow: InfoWindow(title: widget.destinationTitle),
        icon: destinationIcon,
      ),
    );
    setState(() {});
  }

  Future<void> getNewService({bool coupon = false}) async {
    appStore.setLoading(true);
    Map req = {
      "pick_lat": widget.sourceLatLog.latitude,
      "pick_lng": widget.sourceLatLog.longitude,
      "drop_lat": widget.destinationLatLog.latitude,
      "drop_lng": widget.destinationLatLog.longitude,
      if (coupon) "coupon_xcode": promoCode.text.trim(),
    };
    await estimatePriceList(req).then((value) {
      print("estimatePriceList" + value.data.toString());
      appStore.setLoading(false);
      serviceList.clear();

      serviceList.addAll(value.data!);
      if (serviceList.isNotEmpty) servicesListData = serviceList[0];
      if (serviceList.isNotEmpty)
        paymentMethodType = serviceList[0].paymentMethod!;
      if (serviceList.isNotEmpty)
        cashList = paymentMethodType == 'cash_wallet'
            ? cashList = ['cash', 'wallet']
            : cashList = [paymentMethodType];
      if (serviceList.isNotEmpty) {
        if (serviceList[0].discountAmount != 0) {
          mSelectServiceAmount =
              serviceList[0].subtotal!.toStringAsFixed(fixedDecimal);
        } else {
          mSelectServiceAmount =
              serviceList[0].totalAmount!.toStringAsFixed(fixedDecimal);
        }
      }
      setState(() {});
    }).catchError((error) {
      appStore.setLoading(false);
      toast(error.toString());
    });
  }

  Future<void> getCouponNewService() async {
    appStore.setLoading(true);
    Map req = {
      "pick_lat": widget.sourceLatLog.latitude,
      "pick_lng": widget.sourceLatLog.longitude,
      "drop_lat": widget.destinationLatLog.latitude,
      "drop_lng": widget.destinationLatLog.longitude,
      "coupon_code": promoCode.text.trim(),
    };
    await estimatePriceList(req).then((value) {
      appStore.setLoading(false);
      serviceList.clear();
      serviceList.addAll(value.data!);
      if (serviceList.isNotEmpty) servicesListData = serviceList[selectedIndex];
      if (serviceList.isNotEmpty)
        cashList = paymentMethodType == 'cash_wallet'
            ? cashList = ['cash', 'wallet']
            : cashList = [paymentMethodType];
      if (serviceList.isNotEmpty) {
        if (serviceList[selectedIndex].discountAmount != 0) {
          mSelectServiceAmount = serviceList[selectedIndex]
              .subtotal!
              .toStringAsFixed(fixedDecimal);
        } else {
          mSelectServiceAmount = serviceList[selectedIndex]
              .totalAmount!
              .toStringAsFixed(fixedDecimal);
        }
      }
      setState(() {});
      Navigator.pop(context);
    }).catchError((error) {
      promoCode.clear();
      Navigator.pop(context);

      appStore.setLoading(false);
      toast(error.toString());
    });
  }

  Future<void> setPolyLines({required LatLng sourceLocation,
    required LatLng destinationLocation,
    LatLng? driverLocation}) async {
    // _polyLines.clear();
    polylineCoordinates.clear();
    var result = await polylinePoints.getRouteBetweenCoordinates(
      googleMapAPIKey,
      PointLatLng(sourceLocation.latitude, sourceLocation.longitude),
      rideRequest != null &&
          (rideRequest!.status == ACCEPTED ||
              rideRequest!.status == ARRIVING ||
              rideRequest!.status == ARRIVED)
          ? PointLatLng(driverLocation!.latitude, driverLocation.longitude)
          : PointLatLng(
          destinationLocation.latitude, destinationLocation.longitude),
    );
    if (result.points.isNotEmpty) {
      result.points.forEach((element) {
        polylineCoordinates.add(LatLng(element.latitude, element.longitude));
      });
      _polyLines.add(Polyline(
        visible: true,
        width: 5,
        polylineId: PolylineId('poly'),
        color: Color.fromARGB(255, 40, 122, 198),
        points: polylineCoordinates,
      ));
      setState(() {});
    }
  }

  onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  Future<void> saveBookingData() async {
    if (isOther == false && nameController.text.isEmpty) {
      return toast(language.nameFieldIsRequired);
    } else if (isOther == false && phoneController.text.isEmpty) {
      return toast(language.phoneNumberIsRequired);
    }
    appStore.setLoading(true);

    Map req = {
      "rider_id": sharedPref.getInt(USER_ID).toString(),
      "service_id": servicesListData!.id.toString(),
      "datetime": DateTime.now().toString(),
      "start_latitude": widget.sourceLatLog.latitude.toString(),
      "start_longitude": widget.sourceLatLog.longitude.toString(),
      "start_address": widget.sourceTitle,
      "end_latitude": widget.destinationLatLog.latitude.toString(),
      "end_longitude": widget.destinationLatLog.longitude.toString(),
      "end_address": widget.destinationTitle,
      "seat_count": servicesListData!.capacity.toString(),
      "status": NEW_RIDE_REQUESTED,
      "payment_type": isOther == false
          ? 'cash'
          : paymentMethodType == 'cash_wallet'
          ? 'cash'
          : paymentMethodType,
      if (promoCode.text.isNotEmpty) "coupon_code": promoCode.text,
      "is_schedule": 0,
      if (isOther == false) "is_ride_for_other": 1,
      if (isOther == false)
        "other_rider_data": {
          "name": nameController.text.trim(),
          "contact_number": phoneController.text.trim(),
        }
    };

    log('$req');
    debugPrint("===========bookingInfo======> $req");
    await saveRideRequest(req).then((value) async {
      rideRequestId = value.rideRequestId!;
      widget.isCurrentRequest = true;
      isBooking = true;
      appStore.setLoading(false);
      setState(() {});
    }).catchError((error) {
      appStore.setLoading(false);
      toast(error.toString());
    });
  }

  mqttForUser() async {
    print("mqttForUser");
    client.setProtocolV311();
    client.logging(on: true);
    client.keepAlivePeriod = 120;
    client.autoReconnect = true;
    try {
      await client.connect();
    } on NoConnectionException catch (e) {
      debugPrint(e.toString());
      client.connect();
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      client.onSubscribed = onSubscribed;

      debugPrint('connected');
    } else {
      client.connect();
    }

    void onconnected() {
      debugPrint('connected');
    }

    client.subscribe(
        'ride_request_status_' + sharedPref.getInt(USER_ID).toString(),
        MqttQos.atLeastOnce);

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final MqttPublishMessage recMess = c![0].payload as MqttPublishMessage;
      final pt =
      MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      print("jsonDecode(pt)['success_type']" +
          jsonDecode(pt)['success_type'].toString());

      if (jsonDecode(pt)['success_type'] == ACCEPTED ||
          jsonDecode(pt)['success_type'] == ARRIVING ||
          jsonDecode(pt)['success_type'] == ARRIVED ||
          jsonDecode(pt)['success_type'] == IN_PROGRESS) {
        isBooking = true;
        getCurrentRequest();
      } else if (jsonDecode(pt)['success_type'] == CANCELED) {
        print("yhaaa gya4");
        launchScreen(context, RiderDashBoardScreen(), isNewTask: true);
      } else if (jsonDecode(pt)['success_type'] == COMPLETED) {
        print("yhaaa gya3");
        if (timer != null) timer!.cancel();
        getCurrentRequest();
      } else if (appStore.isRiderForAnother == "1" &&
          jsonDecode(pt)['success_type'] == SUCCESS) {
        print("yhaaa gya2");
        if (timer != null) timer!.cancel();
        launchScreen(context, RiderDashBoardScreen(), isNewTask: true);
      }
    });
    client.onConnected = onconnected;
  }

  void onConnected() {
    log('Connected');
  }

  void onSubscribed(String topic) {
    log('Subscription confirmed for topic $topic');
  }

  Future<void> getUserDetailLocation() async {
    getUserDetail(userId: driverData!.id).then((value) {
      driverLatitudeLocation = LatLng(double.parse(value.data!.latitude!),
          double.parse(value.data!.longitude!));
      getServiceList();
    }).catchError((error) {
      log(error.toString());
    });
  }

  Future<void> cancelRequest() async {
    Map req = {
      "id": rideRequestId == 0 ? widget.id : rideRequestId,
      "cancel_by": 'rider',
      "status": CANCELED,
    };
    await rideRequestUpdate(
        request: req,
        rideId: rideRequestId == 0 ? widget.id : rideRequestId)
        .then((value) async {
      launchScreen(context, RiderDashBoardScreen(), isNewTask: true);
      toast(value.message);
    }).catchError((error) {
      log(error.toString());
    });
  }

  @override
  void dispose() {
    Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
        .then((value) {
      polylineSource = LatLng(value.latitude, value.longitude);
    });
    if (timer != null) timer!.cancel();
    super.dispose();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  Widget mSomeOnElse() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child:
                Text(language.lblRideInformation, style: boldTextStyle()),
              ),
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.close)),
              ),
            ],
          ),
          SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: AppTextField(
              controller: nameController,
              autoFocus: false,
              isValidationRequired: false,
              textFieldType: TextFieldType.NAME,
              keyboardType: TextInputType.name,
              errorThisFieldRequired: language.thisFieldRequired,
              decoration: inputDecoration(context, label: language.enterName),
            ),
          ),
          SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: AppTextField(
              controller: phoneController,
              autoFocus: false,
              isValidationRequired: false,
              textFieldType: TextFieldType.PHONE,
              keyboardType: TextInputType.number,
              errorThisFieldRequired: language.thisFieldRequired,
              decoration:
              inputDecoration(context, label: language.enterContactNumber),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: AppButtonWidget(
              width: MediaQuery
                  .of(context)
                  .size
                  .width,
              text: language.done,
              textStyle: boldTextStyle(color: Colors.white),
              color: primaryColor,
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leadingWidth: 50,
        leading: inkWellWidget(
          onTap: () {
            if (isBooking) {
              showConfirmDialogCustom(context,
                  primaryColor: primaryColor,
                  title: language.areYouSureYouWantToCancelThisRide,
                  dialogType: DialogType.CONFIRMATION, onAccept: (_) {
                    sharedPref.remove(REMAINING_TIME);
                    sharedPref.remove(IS_TIME);
                    print("9099090909090909090900909090909909");

                    //show bottom sheet here and then cancel the request
                    //Navigator.pop(context);
                    Future.delayed(
                      Duration.zero,
                    ).then((value) {
                      showModalBottomSheet(
                        isScrollControlled: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(defaultRadius),
                              topRight: Radius.circular(defaultRadius)),
                        ),
                        context: context,
                        builder: (_) {
                          return StatefulBuilder(
                              builder: (context, st) {
                                return SizedBox(
                                  height: 475,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    child: ListView(
                                      children: [
                                        Padding(
                                          padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 20),
                                          child: Row(
                                            mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                "Cancel trip?",
                                                style: TextStyle(
                                                    color: Theme
                                                        .of(context)
                                                        .primaryColor,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight
                                                        .bold),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: Text(
                                                  language.skip,
                                                  style: TextStyle(
                                                      color:
                                                      Theme
                                                          .of(context)
                                                          .primaryColor,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight
                                                          .bold),
                                                ),
                                              )
                                            ],
                                          ),
                                        ),
                                        Divider(
                                          height: 5,
                                          color: Colors.black12,
                                          thickness: 1.2,
                                        ),
                                        Padding(
                                          padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 20),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment
                                                .start,
                                            children: [
                                              const SizedBox(
                                                height: 20,
                                              ),
                                              Text(
                                                language.whyToCancelTrip,
                                                style: TextStyle(
                                                    color: Theme
                                                        .of(context)
                                                        .primaryColor,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight
                                                        .bold),
                                              ),
                                              const SizedBox(
                                                height: 5,
                                              ),
                                              Text(
                                                language.Optional,
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight
                                                        .normal),
                                              ),
                                              InkWell(
                                                onTap: () =>
                                                    st(() {
                                                      index = 1;
                                                    }),
                                                child: _rowBuilder(
                                                    text: language
                                                        .requestedWrongVechile,
                                                    value: index == 1),
                                              ),
                                              InkWell(
                                                onTap: () =>
                                                    st(() {
                                                      index = 2;
                                                    }),
                                                child: _rowBuilder(
                                                    text: language
                                                        .selectedWrongDropOff,
                                                    value: index == 2),
                                              ),
                                              InkWell(
                                                onTap: () =>
                                                    st(() {
                                                      index = 3;
                                                    }),
                                                child: _rowBuilder(
                                                    text: language
                                                        .selectedWrongPickUp,
                                                    value: index == 3),
                                              ),
                                              InkWell(
                                                onTap: () =>
                                                    st(() {
                                                      index = 4;
                                                    }),
                                                child: _rowBuilder(
                                                    text: language
                                                        .waitingTimeTooLong,
                                                    value: index == 4),
                                              ),
                                              InkWell(
                                                onTap: () =>
                                                    st(() {
                                                      index = 5;
                                                    }),
                                                child: _rowBuilder(
                                                    text: language
                                                        .requestedByAccident,
                                                    value: index == 5),
                                              ),
                                              InkWell(
                                                  onTap: () =>
                                                      st(() {
                                                        index = 6;
                                                      }),
                                                  child: _rowBuilder(
                                                      text: language.Others,
                                                      value: index == 6)),
                                              SizedBox(
                                                  width:
                                                  MediaQuery
                                                      .of(context)
                                                      .size
                                                      .width,
                                                  child: ElevatedButton(
                                                      onPressed: () {
                                                        Navigator.pop(context);
                                                        cancelRequest();
                                                      },
                                                      child: Text(
                                                          language.Submit)))
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                          );
                        },
                      );
                    });

                    //cancelRequest();
                  });
            } else {
              launchScreen(context, RiderDashBoardScreen(), isNewTask: true);
            }
          },
          child: Container(
            margin: EdgeInsets.only(left: 8),
            padding: EdgeInsets.all(0),
            decoration:
            BoxDecoration(color: primaryColor, shape: BoxShape.circle),
            child: Icon(Icons.close, color: Colors.white, size: 20),
          ),
        ),
      ),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          GoogleMap(
              mapToolbarEnabled: false,
              zoomControlsEnabled: false,
              onMapCreated: onMapCreated,
              initialCameraPosition: CameraPosition(
                  target: alokLatLon ?? widget.sourceLatLog, zoom: zoomLevel),
              markers: alokMarkerSet,
              onCameraMove: (position) {
                zoomLevel = position.zoom;
                bearing = position.bearing;
                tilt = position.tilt;
              },
              //markers,
              mapType: MapType.normal,
              polylines: newTestPolyline //alok_polyline //_polyLines,
          ),

          /* GoogleMap(
              markers: alokMarkerSet, //markers,
              mapType: MapType.normal,
            onMapCreated: onMapCreated,
            polylines: Set<Polyline>.of(testList),
            initialCameraPosition: CameraPosition(target: widget.sourceLatLog, zoom: 11.0)
          ),*/

          !isBooking
              ? Stack(
            children: [
              Visibility(
                visible: serviceList.isNotEmpty,
                child: Container(
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(defaultRadius),
                          topRight: Radius.circular(defaultRadius))),
                  child: SingleChildScrollView(
                    child: isRideSelection == false &&
                        appStore.isRiderForAnother == "1"
                        ? Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              alignment: Alignment.center,
                              margin: EdgeInsets.only(bottom: 16),
                              height: 5,
                              width: 70,
                              decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius:
                                  BorderRadius.circular(
                                      defaultRadius)),
                            ),
                          ),
                          Text(language.lblWhoRiding,
                              style: primaryTextStyle(size: 18)),
                          SizedBox(height: 20),
                          Row(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [
                              inkWellWidget(
                                  child: Column(
                                    mainAxisAlignment:
                                    MainAxisAlignment.center,
                                    children: [
                                      Stack(
                                        children: [
                                          Container(
                                            height: 70,
                                            width: 70,
                                            decoration: BoxDecoration(
                                                shape:
                                                BoxShape.circle,
                                                border: Border.all(
                                                    color:
                                                    textSecondaryColorGlobal,
                                                    width: 1)),
                                            padding:
                                            EdgeInsets.all(12),
                                            child: Image.asset(
                                                ic_add_user,
                                                fit: BoxFit.fill),
                                          ),
                                          if (!isOther)
                                            Container(
                                              height: 70,
                                              width: 70,
                                              decoration:
                                              BoxDecoration(
                                                  shape: BoxShape
                                                      .circle,
                                                  color: Colors
                                                      .black54),
                                              child: Icon(
                                                  Icons.check,
                                                  color:
                                                  Colors.white),
                                            ),
                                        ],
                                      ),
                                      SizedBox(height: 10),
                                      Text(language.lblSomeoneElse,
                                          style:
                                          primaryTextStyle()),
                                    ],
                                  ),
                                  onTap: () {
                                    isOther = false;
                                    showDialog(
                                      context: context,
                                      builder: (_) {
                                        return StatefulBuilder(
                                            builder: (BuildContext
                                            context,
                                                StateSetter
                                                setState) {
                                              return AlertDialog(
                                                contentPadding:
                                                EdgeInsets.all(0),
                                                content: mSomeOnElse(),
                                              );
                                            });
                                      },
                                    ).then((value) {
                                      setState(() {});
                                    });
                                    setState(() {});
                                  }),
                              SizedBox(width: 30),
                              inkWellWidget(
                                  child: Column(
                                    children: [
                                      Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                            BorderRadius
                                                .circular(40),
                                            child:
                                            commonCachedNetworkImage(
                                                appStore
                                                    .userProfile
                                                    .validate(),
                                                height: 70,
                                                width: 70,
                                                fit: BoxFit
                                                    .cover),
                                          ),
                                          if (isOther)
                                            Container(
                                              height: 70,
                                              width: 70,
                                              decoration:
                                              BoxDecoration(
                                                  shape: BoxShape
                                                      .circle,
                                                  color: Colors
                                                      .black54),
                                              child: Icon(
                                                  Icons.check,
                                                  color:
                                                  Colors.white),
                                            ),
                                        ],
                                      ),
                                      SizedBox(height: 10),
                                      Text(language.lblYou,
                                          style:
                                          primaryTextStyle()),
                                    ],
                                  ),
                                  onTap: () {
                                    isOther = true;
                                    setState(() {});
                                  })
                            ],
                          ),
                          SizedBox(height: 20),
                          Text(language.lblWhoRidingMsg,
                              style: secondaryTextStyle()),
                          SizedBox(height: 8),
                          AppButtonWidget(
                            color: primaryColor,
                            onTap: () async {
                              if (!isOther) {
                                if (nameController
                                    .text.isEmptyOrNull ||
                                    phoneController
                                        .text.isEmptyOrNull) {
                                  showDialog(
                                    context: context,
                                    builder: (_) {
                                      return StatefulBuilder(
                                          builder:
                                              (BuildContext context,
                                              StateSetter
                                              setState) {
                                            return AlertDialog(
                                              contentPadding:
                                              EdgeInsets.all(0),
                                              content: mSomeOnElse(),
                                            );
                                          });
                                    },
                                  ).then((value) {
                                    setState(() {});
                                  });
                                } else {
                                  isRideSelection = true;
                                }
                              } else {
                                isRideSelection = true;
                              }
                              setState(() {});
                            },
                            text: language.lblNext,
                            textStyle:
                            boldTextStyle(color: Colors.white),
                            width:
                            MediaQuery
                                .of(context)
                                .size
                                .width,
                          ),
                        ],
                      ),
                    )
                        : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            alignment: Alignment.center,
                            margin:
                            EdgeInsets.only(bottom: 8, top: 16),
                            height: 5,
                            width: 70,
                            decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(
                                    defaultRadius)),
                          ),
                        ),
                        SingleChildScrollView(
                          padding:
                          EdgeInsets.only(left: 8, right: 8),
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: serviceList.map((e) {
                              print(
                                  "83476589457698674554 ${e.serviceImage}");
                              return GestureDetector(
                                onTap: () {
                                  if (e.discountAmount != 0) {
                                    mSelectServiceAmount =
                                        e.subtotal!.toStringAsFixed(
                                            fixedDecimal);
                                  } else {
                                    mSelectServiceAmount = e
                                        .totalAmount!
                                        .toStringAsFixed(
                                        fixedDecimal);
                                  }
                                  selectedIndex =
                                      serviceList.indexOf(e);
                                  servicesListData = e;
                                  paymentMethodType =
                                  e.paymentMethod!;
                                  cashList = paymentMethodType ==
                                      'cash_wallet'
                                      ? cashList = [
                                    'cash',
                                    'wallet'
                                  ]
                                      : cashList = [
                                    paymentMethodType
                                  ];
                                  setState(() {});
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      vertical: 16, horizontal: 16),
                                  margin: EdgeInsets.only(
                                      top: 16, left: 8, right: 8),
                                  decoration: BoxDecoration(
                                    color: selectedIndex ==
                                        serviceList.indexOf(e)
                                        ? primaryColor
                                        : Colors.white,
                                    border: Border.all(
                                        color: dividerColor),
                                    borderRadius:
                                    BorderRadius.circular(
                                        defaultRadius),
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                    MainAxisAlignment.start,
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(height: 8),
                                      // Image.asset(
                                      //     "images/ic_logo_white.png",
                                      //     height: 50,
                                      //     width: 100,
                                      //     fit: BoxFit.cover,
                                      //     alignment:
                                      //     Alignment.center),
                                      Image.network(
                                          "https://app.sanjeevaniplus.com/service_images/${e
                                              .serviceImage ?? ""}",
                                          errorBuilder: (context,
                                              error, stackTrace) {
                                            return Image.asset(
                                                "images/ic_logo_white2.png",
                                                height: 70,
                                                width: 100,
                                                fit: BoxFit.fill,
                                                alignment:
                                                Alignment.center);
                                          },
                                          height: 50,
                                          width: 100,
                                          fit: BoxFit.cover,
                                          alignment:
                                          Alignment.center),
                                      // commonCachedNetworkImage(e.serviceImage.validate(),
                                      //     height: 50,
                                      //     width: 100,
                                      //     fit: BoxFit.cover,
                                      //     alignment:
                                      //         Alignment.center),
                                      SizedBox(height: 8),
                                      Text(e.name.validate(),
                                          style: boldTextStyle(
                                              color: selectedIndex ==
                                                  serviceList
                                                      .indexOf(
                                                      e)
                                                  ? Colors.white
                                                  : primaryColor)),
                                      SizedBox(height: 8),
                                      Row(
                                        crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                        children: [
                                          Text(language.capacity,
                                              style: secondaryTextStyle(
                                                  size: 12,
                                                  color: selectedIndex ==
                                                      serviceList
                                                          .indexOf(
                                                          e)
                                                      ? Colors.white
                                                      : primaryColor)),
                                          SizedBox(width: 4),
                                          Text(
                                              e.capacity
                                                  .toString() +
                                                  " + 1",
                                              style: secondaryTextStyle(
                                                  color: selectedIndex ==
                                                      serviceList
                                                          .indexOf(
                                                          e)
                                                      ? Colors.white
                                                      : primaryColor)),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Text(
                                            appStore.currencyPosition ==
                                                LEFT
                                                ? '${appStore.currencyCode} ${e
                                                .totalAmount!.toStringAsFixed(
                                                fixedDecimal)}'
                                                : '${e.totalAmount!
                                                .toStringAsFixed(
                                                fixedDecimal)} ${appStore
                                                .currencyCode}',
                                            style: boldTextStyle(
                                              color: selectedIndex ==
                                                  serviceList
                                                      .indexOf(
                                                      e)
                                                  ? Colors.white
                                                  : primaryColor,
                                              textDecoration:
                                              e.discountAmount !=
                                                  0
                                                  ? TextDecoration
                                                  .lineThrough
                                                  : null,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          inkWellWidget(
                                            onTap: () {
                                              showModalBottomSheet(
                                                backgroundColor:
                                                primaryColor,
                                                context: context,
                                                shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius
                                                        .only(
                                                        topRight: Radius
                                                            .circular(
                                                            defaultRadius),
                                                        topLeft: Radius
                                                            .circular(
                                                            defaultRadius))),
                                                builder: (_) {
                                                  return CarDetailWidget(
                                                      service: e);
                                                },
                                              );
                                            },
                                            child: Icon(
                                                Icons
                                                    .info_outline_rounded,
                                                size: 18,
                                                color: selectedIndex ==
                                                    serviceList
                                                        .indexOf(
                                                        e)
                                                    ? Colors.white
                                                    : primaryColor),
                                          ),
                                        ],
                                      ),
                                      if (e.discountAmount != 0)
                                        SizedBox(height: 8),
                                      if (e.discountAmount != 0)
                                        Text(
                                          appStore.currencyPosition ==
                                              LEFT
                                              ? '${appStore.currencyCode} ${e
                                              .subtotal!.toStringAsFixed(
                                              fixedDecimal)}'
                                              : '${e.subtotal!.toStringAsFixed(
                                              fixedDecimal)} ${appStore
                                              .currencyCode}',
                                          style: boldTextStyle(
                                            color: selectedIndex ==
                                                serviceList
                                                    .indexOf(e)
                                                ? Colors.white
                                                : primaryColor,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        SizedBox(height: 8),
                        inkWellWidget(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) {
                                return StatefulBuilder(builder:
                                    (BuildContext context,
                                    StateSetter setState) {
                                  return Observer(
                                      builder: (context) {
                                        return Stack(
                                          children: [
                                            AlertDialog(
                                              contentPadding:
                                              EdgeInsets.all(16),
                                              content:
                                              SingleChildScrollView(
                                                child: Column(
                                                  mainAxisSize:
                                                  MainAxisSize.min,
                                                  crossAxisAlignment:
                                                  CrossAxisAlignment
                                                      .start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                      children: [
                                                        Text(
                                                            language
                                                                .paymentMethod,
                                                            style:
                                                            boldTextStyle()),
                                                        inkWellWidget(
                                                          onTap: () {
                                                            Navigator.pop(
                                                                context);
                                                          },
                                                          child:
                                                          Container(
                                                            padding:
                                                            EdgeInsets
                                                                .all(6),
                                                            decoration: BoxDecoration(
                                                                color:
                                                                primaryColor,
                                                                shape: BoxShape
                                                                    .circle),
                                                            child: Icon(
                                                                Icons
                                                                    .close,
                                                                color: Colors
                                                                    .white),
                                                          ),
                                                        )
                                                      ],
                                                    ),
                                                    SizedBox(height: 4),
                                                    Text(
                                                        language
                                                            .chooseYouPaymentLate,
                                                        style:
                                                        secondaryTextStyle()),
                                                    Text(
                                                        isOther
                                                            .toString(),
                                                        style:
                                                        secondaryTextStyle()),
                                                    SizedBox(
                                                        height: 16),
                                                    isOther == false
                                                        ? RadioListTile(
                                                      contentPadding:
                                                      EdgeInsets
                                                          .zero,
                                                      controlAffinity:
                                                      ListTileControlAffinity
                                                          .trailing,
                                                      activeColor:
                                                      primaryColor,
                                                      value:
                                                      'cash',
                                                      groupValue:
                                                      'cash',
                                                      title: Text(
                                                          language
                                                              .cash,
                                                          style:
                                                          boldTextStyle()),
                                                      onChanged:
                                                          (String?
                                                      val) {},
                                                    )
                                                        : Column(
                                                      children:
                                                      cashList
                                                          .map((e) {
                                                        return RadioListTile(
                                                          contentPadding:
                                                          EdgeInsets.zero,
                                                          controlAffinity:
                                                          ListTileControlAffinity
                                                              .trailing,
                                                          activeColor:
                                                          primaryColor,
                                                          value:
                                                          e,
                                                          groupValue: paymentMethodType ==
                                                              'cash_wallet'
                                                              ? 'cash'
                                                              : paymentMethodType,
                                                          title: Text(
                                                              e
                                                                  .capitalizeFirstLetter(),
                                                              style: boldTextStyle()),
                                                          onChanged:
                                                              (String?
                                                          val) {
                                                            paymentMethodType =
                                                            val!;
                                                            setState(
                                                                    () {});
                                                          },
                                                        );
                                                      }).toList(),
                                                    ),
                                                    SizedBox(
                                                        height: 16),
                                                    AppTextField(
                                                      controller:
                                                      promoCode,
                                                      autoFocus: false,
                                                      textFieldType:
                                                      TextFieldType
                                                          .EMAIL,
                                                      keyboardType:
                                                      TextInputType
                                                          .emailAddress,
                                                      errorThisFieldRequired:
                                                      language
                                                          .thisFieldRequired,
                                                      readOnly: true,
                                                      onTap: () async {
                                                        var data =
                                                        await showModalBottomSheet(
                                                          context:
                                                          context,
                                                          builder: (_) {
                                                            return CouPonWidget();
                                                          },
                                                        );
                                                        if (data !=
                                                            null) {
                                                          promoCode
                                                              .text =
                                                              data;
                                                        }
                                                      },
                                                      decoration: inputDecoration(
                                                          context,
                                                          label: language
                                                              .enterPromoCode,
                                                          suffixIcon: promoCode
                                                              .text
                                                              .isNotEmpty
                                                              ? inkWellWidget(
                                                            onTap:
                                                                () {
                                                              promoCode.clear();
                                                              getNewService(
                                                                  coupon: false);
                                                            },
                                                            child: Icon(
                                                                Icons.close,
                                                                color: Colors
                                                                    .black,
                                                                size: 25),
                                                          )
                                                              : null),
                                                    ),
                                                    SizedBox(
                                                        height: 16),
                                                    AppButtonWidget(
                                                      width:
                                                      MediaQuery
                                                          .of(
                                                          context)
                                                          .size
                                                          .width,
                                                      text: language
                                                          .confirm,
                                                      textStyle:
                                                      boldTextStyle(
                                                          color: Colors
                                                              .white),
                                                      color:
                                                      primaryColor,
                                                      onTap: () {
                                                        if (promoCode
                                                            .text
                                                            .isNotEmpty) {
                                                          getCouponNewService();
                                                          //getNewService(coupon: true);
                                                        } else {
                                                          // getNewService();
                                                          Navigator.pop(
                                                              context);
                                                        }
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Visibility(
                                              visible:
                                              appStore.isLoading,
                                              child: Observer(
                                                  builder: (context) {
                                                    return loaderWidget();
                                                  }),
                                            ),
                                          ],
                                        );
                                      });
                                });
                              },
                            ).then((value) {
                              setState(() {});
                            });
                          },
                          child: Container(
                            margin:
                            EdgeInsets.fromLTRB(16, 8, 16, 16),
                            decoration: BoxDecoration(
                                border:
                                Border.all(color: dividerColor),
                                borderRadius: BorderRadius.circular(
                                    defaultRadius)),
                            padding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(language.paymentVia,
                                    style: secondaryTextStyle(
                                        size: 12)),
                                SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(4),
                                      margin:
                                      EdgeInsets.only(top: 4),
                                      decoration: BoxDecoration(
                                          color: primaryColor,
                                          borderRadius:
                                          BorderRadius.circular(
                                              defaultRadius)),
                                      child: Icon(
                                          Icons.wallet_outlined,
                                          size: 20,
                                          color: Colors.white),
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                        children: [
                                          Text(
                                              isOther == false
                                                  ? 'Cash'
                                                  : paymentMethodType ==
                                                  'cash_wallet'
                                                  ? 'Cash'
                                                  : paymentMethodType
                                                  .capitalizeFirstLetter(),
                                              style: boldTextStyle(
                                                  size: 14)),
                                          SizedBox(height: 4),
                                          SizedBox(height: 4),
                                          Text(
                                              paymentMethodType !=
                                                  'cash_wallet'
                                                  ? language
                                                  .forInstantPayment
                                                  : language
                                                  .lblPayWhenEnds,
                                              style:
                                              secondaryTextStyle(
                                                  size: 12)),
                                          if (mSelectServiceAmount !=
                                              null &&
                                              paymentMethodType !=
                                                  'cash_wallet' &&
                                              paymentMethodType ==
                                                  'wallet' &&
                                              double.parse(
                                                  mSelectServiceAmount!) >=
                                                  mTotalAmount
                                                      .toDouble())
                                            Padding(
                                              padding:
                                              EdgeInsets.only(
                                                  top: 4),
                                              child: Text(
                                                  language
                                                      .lblLessWalletAmount,
                                                  style: boldTextStyle(
                                                      size: 12,
                                                      color: Colors
                                                          .red,
                                                      letterSpacing:
                                                      0.5,
                                                      weight:
                                                      FontWeight
                                                          .w500)),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding:
                          EdgeInsets.only(left: 16, right: 16),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: AppButtonWidget(
                                  color: primaryColor,
                                  onTap: () {
                                    saveBookingData();
                                  },
                                  text: language.bookNow,
                                  textStyle: boldTextStyle(
                                      color: Colors.white),
                                  width: MediaQuery
                                      .of(context)
                                      .size
                                      .width,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
              Visibility(
                visible: appStore.isLoading,
                child: Observer(builder: (context) {
                  return loaderWidget();
                }),
              ),
              if (!appStore.isLoading && serviceList.isEmpty)
                emptyWidget()
            ],
          )
              : Container(
                decoration: BoxDecoration(
                    //color: Colors.white,
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(defaultRadius),
                        topRight: Radius.circular(defaultRadius))),

                child: rideRequest != null
                    ? rideRequest!.status == NEW_RIDE_REQUESTED
                    ? Container(
                  color: Colors.white,
                      child: BookingWidget(
                      id: rideRequestId == 0
                          ? widget.id
                          : rideRequestId),
                    )
                    : Container(
                  height: 400,
                      child: MediaQuery.removePadding(
                        removeTop: true,
                        context: context,
                        child: DraggableScrollableSheet(initialChildSize: 0.45,//expand: false,
                          maxChildSize:1,
                  minChildSize: 0.45, builder: (context, scrollController) {
                            scrollController.addListener(() {
                              //
                            });
                        return RideAcceptWidget(
                            rideRequest: rideRequest, driverData: driverData,scrollController: scrollController,);
                  },),
                      ),
                    ) /*RideAcceptWidget(   sdsd
                                  rideRequest: rideRequest, driverData: driverData)*/
                    : Container(
                  color: Colors.white,
                      child: BookingWidget(
                      id: rideRequestId,
                      // id: rideRequestId == 0 ? widget.id : rideRequestId,
                      isLast: true),
                    ),
              ),
        ],
      ),
    );
  }

  Widget _rowBuilder({required bool value, required String text}) =>

      Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          AbsorbPointer(
            absorbing: true,
            child: Container(
              alignment: Alignment.centerLeft,
              width: 40,
              child: Radio(
                value: value,
                groupValue: true,
                onChanged: (value) => null,
                fillColor: MaterialStateColor.resolveWith((states) =>
                Theme
                    .of(context)
                    .primaryColor),
                activeColor: Theme
                    .of(context)
                    .primaryColor,
              ),
            ),
          ),
          Text(text)
        ],
      );
  int index = -1;
}
