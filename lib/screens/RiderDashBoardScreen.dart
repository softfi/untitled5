import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../components/DrawerWidget.dart';
import '../main.dart';
import '../model/CurrentRequestModel.dart';
import '../model/NearByDriverListModel.dart';
import '../model/RearestHospitalModel/nearest_hospital_data.dart';
import '../model/TextModel.dart';
import '../network/RestApis.dart';
import '../screens/EmergencyContactScreen.dart';
import '../screens/MyRidesScreen.dart';
import '../screens/MyWalletScreen.dart';
import '../screens/OrderDetailScreen.dart';
import '../screens/ReviewScreen.dart';
import '../utils/Colors.dart';
import '../utils/Common.dart';
import '../utils/Constants.dart';
import '../utils/DataProvider.dart';
import '../utils/Extensions/AppButtonWidget.dart';
import '../utils/Extensions/ConformationDialog.dart';
import '../utils/Extensions/LiveStream.dart';
import '../utils/Extensions/StringExtensions.dart';
import '../utils/Extensions/app_common.dart';
import '../utils/Extensions/app_textfield.dart';
import '../utils/images.dart';
import 'EditProfileScreen.dart';
import 'HelpAndSupportScreen.dart';
import 'LocationPermissionScreen.dart';
import 'NewEstimateRideListWidget.dart';
import 'NotificationScreen.dart';
import 'RiderWidget.dart';
import 'SettingScreen.dart';


int RIDE_REQUEST_ID_BY_ALOK=0;

class RiderDashBoardScreen extends StatefulWidget {
  @override
  RiderDashBoardScreenState createState() => RiderDashBoardScreenState();
}

class RiderDashBoardScreenState extends State<RiderDashBoardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  ///////
  LatLng? sourceLocation;

  String currentLocationText = "";

  List<TexIModel> list = getBookList();

  // List<Marker> markers = [];
  //Set<Marker> markers = Set();
  List<Marker> markers = <Marker>[];
  List<MarkerList> markersDataList = [];
  Set<Polyline> _polyLines = Set<Polyline>();
  List<LatLng> polylineCoordinates = [];
  late PolylinePoints polylinePoints;
  OnRideRequest? servicesListData;

  double cameraZoom = 14;
  double cameraTilt = 0;
  double cameraBearing = 30;
  int onTapIndex = 0;

  int selectIndex = 0;
  String sourceLocationTitle = '';

  late StreamSubscription<ServiceStatus> serviceStatusStream;

  LocationPermission? permissionData;

  late BitmapDescriptor riderIcon;
  late BitmapDescriptor driverIcon;
  List<NearByDriverListModel>? nearDriverModel;
  late BitmapDescriptor myMarker;

  //////
  // alok data
  List<Marker> test = List.empty(growable: true);
  double lat = 26.8463;
  double long = 80.9263;

  @override
  void initState() {
    super.initState();
    // addTest();
    locationPermission();
    afterBuildCreated(() {
      init();
      getCurrentRequest();
    });
  }

  void init() async {
    getCurrentUserLocation();

    riderIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: 2.5), SourceIcon);
    driverIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: 2.2), MultipleDriver);
    myMarker = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: 0.5, size: Size(30, 30)),
        markerIcon);
    await getAppSetting().then((value) {
      print("value.rideSetting==> 2 ");
      if (value.walletSetting!.isNotEmpty) {
        appStore.setWalletPresetTopUpAmount(value.walletSetting!
                .firstWhere((element) => element.key == PRESENT_TOPUP_AMOUNT)
                .value ??
            '10|20|30');
        if (value.walletSetting!
                .firstWhere((element) => element.key == MIN_AMOUNT_TO_ADD)
                .value !=
            null)
          appStore.setMinAmountToAdd(int.parse(value.walletSetting!
              .firstWhere((element) => element.key == MIN_AMOUNT_TO_ADD)
              .value!));
        if (value.walletSetting!
                .firstWhere((element) => element.key == MAX_AMOUNT_TO_ADD)
                .value !=
            null)
          appStore.setMaxAmountToAdd(int.parse(value.walletSetting!
              .firstWhere((element) => element.key == MAX_AMOUNT_TO_ADD)
              .value!));
      }

      if (value.rideSetting!.isNotEmpty) {
        appStore.setWalletTipAmount(value.rideSetting!
                .firstWhere((element) => element.key == PRESENT_TIP_AMOUNT)
                .value ??
            '10|20|30');
        print(
            "value.rideSetting==> ${value.rideSetting!.firstWhere((element) => element.key == RIDE_FOR_OTHER).value}");

        appStore.setIsRiderForAnother(value.rideSetting!
                .firstWhere((element) => element.key == RIDE_FOR_OTHER)
                .value ??
            "0");
        appStore.setRiderMinutes(value.rideSetting!
                .firstWhere(
                    (element) => element.key == MAX_TIME_FOR_RIDER_MINUTE)
                .value ??
            '4');
      }
      if (value.currencySetting != null) {
        appStore
            .setCurrencyCode(value.currencySetting!.symbol ?? currencySymbol);
        appStore
            .setCurrencyName(value.currencySetting!.code ?? currencyNameConst);
        appStore.setCurrencyPosition(value.currencySetting!.position ?? LEFT);
      }
    }).catchError((error) {
      log('${error.toString()}');
    });
    polylinePoints = PolylinePoints();
  }

  Future<void> getCurrentUserLocation() async {
    permissionData = await Geolocator.requestPermission();
    if (permissionData != LocationPermission.denied) {
      final geoPosition = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high)
          .catchError((error) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => LocationPermissionScreen()));
      });
      sourceLocation = LatLng(geoPosition.latitude, geoPosition.longitude);
      setMarkersByLatLng(geoPosition.latitude, geoPosition.longitude);
      debugPrint("========latlng $sourceLocation");
      List<Placemark>? placemarks = await placemarkFromCoordinates(
          geoPosition.latitude, geoPosition.longitude);
      Placemark place = placemarks[0];
      if (place != null) {
        sourceLocationTitle =
            "${place.name != null ? place.name : place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea} ${place.postalCode}, ${place.country}";
        polylineSource = LatLng(geoPosition.latitude, geoPosition.longitude);
        currentLocationText =
            "${place.name} ${place.street} ${place.subLocality} ${place.locality}";
        debugPrint("========sourceLocationTitle ${place.name}");
        debugPrint("========sourceLocationTitle ${place.street}");
        debugPrint("========sourceLocationTitle ${place.isoCountryCode}");
        debugPrint("========sourceLocationTitle ${place.thoroughfare}");
        debugPrint("========sourceLocationTitle ${place.subThoroughfare}");
        debugPrint("========sourceLocationTitle ${place.subLocality}");
        debugPrint("========sourceLocationTitle ${place.locality}");
      }
      markers.add(
        Marker(
          markerId: MarkerId('Order Detail'),
          position: sourceLocation!,
          draggable: true,
          infoWindow: InfoWindow(title: sourceLocationTitle, snippet: ''),
          icon: riderIcon,
        ),
      );
      startLocationTracking();
      getNearByDriverList(latLng: sourceLocation).then((value) async {
        value.data!.forEach((element) {
          markers.add(
            Marker(
              markerId: MarkerId('Driver${element.id}'),
              position: LatLng(double.parse(element.latitude!.toString()),
                  double.parse(element.longitude!.toString())),
              infoWindow: InfoWindow(
                  title: '${element.firstName} ${element.lastName}',
                  snippet: ''),
              icon: driverIcon,
            ),
          );
        });
        setState(() {});
      });
      setState(() {});
    } else {
      permissionData = await Geolocator.requestPermission();
      /*Navigator.push(context,
          MaterialPageRoute(builder: (_) => LocationPermissionScreen()));*/
    }
  }

  Future<void> getCurrentRequest() async {
    await getCurrentRideRequest().then((value) {
      servicesListData = value.rideRequest ?? value.onRideRequest;
      if (servicesListData != null) {
        if (servicesListData!.status != COMPLETED) {
          debugPrint("this is ride id ${servicesListData!.id}");
          RIDE_REQUEST_ID_BY_ALOK=servicesListData!.id!;
          launchScreen(
            context,
            isNewTask: true,
            NewEstimateRideListWidget(
              sourceLatLog: LatLng(
                  double.parse(servicesListData!.startLatitude!),
                  double.parse(servicesListData!.startLongitude!)),
              destinationLatLog: LatLng(
                  double.parse(servicesListData!.endLatitude!),
                  double.parse(servicesListData!.endLongitude!)),
              sourceTitle: servicesListData!.startAddress!,
              destinationTitle: servicesListData!.endAddress!,
              isCurrentRequest: true,
              servicesId: servicesListData!.serviceId,
              id: servicesListData!.id,
            ),
            pageRouteAnimation: PageRouteAnimation.SlideBottomTop,
          );
        } else if (servicesListData!.status == COMPLETED &&
            servicesListData!.isRiderRated == 0) {
          print(
              "000000000000000000000000000000000000aaaaaaaaaaaaaaaaaaaaaa ========>");
          launchScreen(
              context,
              ReviewScreen(
                  rideRequest: servicesListData!, driverData: value.driver),
              pageRouteAnimation: PageRouteAnimation.SlideBottomTop,
              isNewTask: true);
        }
      } else if (value.payment != null &&
          value.payment!.paymentStatus != COMPLETED) {
        launchScreen(
            context, OrderDetailScreen(rideId: value.payment!.rideRequestId),
            pageRouteAnimation: PageRouteAnimation.SlideBottomTop,
            isNewTask: true);
      }
    }).catchError((error) {
      log(error.toString());
    });
  }

  Future<void> locationPermission() async {
    serviceStatusStream =
        Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
      if (status == ServiceStatus.disabled) {
        launchScreen(navigatorKey.currentState!.overlay!.context,
            LocationPermissionScreen());
      } else if (status == ServiceStatus.enabled) {
        getCurrentUserLocation();

        if (Navigator.canPop(navigatorKey.currentState!.overlay!.context)) {
          Navigator.pop(navigatorKey.currentState!.overlay!.context);
        }
      }
    }, onError: (error) {
      //
    });
  }

  Future<void> startLocationTracking() async {
    Map req = {
      "status": "active",
      "latitude": sourceLocation!.latitude.toString(),
      "longitude": sourceLocation!.longitude.toString(),
    };

    await updateStatus(req).then((value) {
      //
    }).catchError((error) {
      log(error);
    });
  }

  setMarkersByLatLng(double latitude, double longitude) async {
    debugPrint("================> hey ${latitude}");
    await getNearHospitalByLatLng(
            lat: latitude.toString(), lng: longitude.toString())
        .then((value) {
      markersDataList.addAll(value.data);
      getMarkers();

      debugPrint("================> this is  ${markersDataList.toString()}");
      setState(() {});
    }).catchError((error) {
      appStore.setLoading(false);
      log(error.toString());
    });
  }

// make sure to initialize before map loading

  List<Marker> getMarkers() {
    for (var data in markersDataList) {
      debugPrint("your LatLng ${data.latitude}, ${data.longitude}");
      markers.add(Marker(
        markerId: MarkerId(data.id.toString()),
        position: LatLng(double.parse(data.latitude.toString()),
            double.parse(data.longitude)),
        //position of marker
        infoWindow: InfoWindow(
            title: data.displayName,
            snippet: data.status,
            onTap: () async {
              debugPrint("your click done");
              launchScreen(
                  context,
                  NewEstimateRideListWidget(
                      sourceLatLog: sourceLocation!,
                      destinationLatLog: LatLng(double.parse(data.latitude),
                          double.parse(data.longitude)),
                      sourceTitle: currentLocationText.toString(),
                      destinationTitle: data.displayName),
                  pageRouteAnimation: PageRouteAnimation.SlideBottomTop);
            }),
        onTap: () => null,
        icon: myMarker,

        // icon : BitmapDescriptor.fromAssetImage(
        //         ImageConfiguration(size: Size(50, 50)), 'images/customMarker.png')
        // icon: BitmapDescriptor.defaultMarker, //Icon for Marker
      ));
      setState(() {});
    }
    return markers;
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  void _onGeoChanged(CameraPosition position) {
    print("position: " + position.target.toString());
    print("zoom: " + position.zoom.toString());
  }

  void sendData() async {}

 late GoogleMapController _controller;

  @override
  Widget build(BuildContext context) {
    LiveStream().on(CHANGE_LANGUAGE, (p0) {
      setState(() {});
    });
    return Scaffold(
      resizeToAvoidBottomInset: false,
      key: _scaffoldKey,
      drawer: Drawer(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 50),
                  Center(
                    child: Container(
                      padding: EdgeInsets.only(right: 8),
                      // decoration: BoxDecoration(border: Border.all(color: primaryColor.withOpacity(0.6)),color: primaryColor.withOpacity(0.2),borderRadius: radius()),
                      child: Observer(builder: (context) {
                        return Column(
                          children: [
                            ClipRRect(
                              borderRadius: radius(),
                              child: commonCachedNetworkImage(
                                  appStore.userProfile.validate().validate(),
                                  height: 70,
                                  width: 70,
                                  fit: BoxFit.cover),
                            ),
                            SizedBox(height: 8),
                            sharedPref.getString(LOGIN_TYPE) != 'mobile' &&
                                    sharedPref.getString(LOGIN_TYPE) != null
                                ? Text(
                                    sharedPref.getString(USER_NAME).validate(),
                                    style: boldTextStyle())
                                : Text(
                                    sharedPref.getString(FIRST_NAME).validate(),
                                    style: boldTextStyle()),
                            SizedBox(height: 4),
                            Text(appStore.userEmail,
                                style: secondaryTextStyle()),
                          ],
                        );
                      }),
                    ),
                  ),
                  Divider(thickness: 1, height: 40),
                  DrawerWidget(
                    title: language.myProfile,
                    iconData: ic_my_profile,
                    onTap: () {
                      Navigator.pop(context);
                      launchScreen(context, EditProfileScreen(),
                          pageRouteAnimation: PageRouteAnimation.Slide);
                    },
                  ),
                  DrawerWidget(
                      title: language.myRides,
                      iconData: ic_my_rides,
                      onTap: () {
                        Navigator.pop(context);
                        launchScreen(context, MyRidesScreen(),
                            pageRouteAnimation: PageRouteAnimation.Slide);
                      }),
                  DrawerWidget(
                      title: language.myWallet,
                      iconData: ic_my_wallet,
                      onTap: () {
                        Navigator.pop(context);
                        launchScreen(context, MyWalletScreen(),
                            pageRouteAnimation: PageRouteAnimation.Slide);
                      }),
                  DrawerWidget(
                      title: language.emergencyContacts,
                      iconData: ic_emergency_contact,
                      onTap: () {
                        Navigator.pop(context);
                        launchScreen(context, EmergencyContactScreen(),
                            pageRouteAnimation: PageRouteAnimation.Slide);
                      }),
                  DrawerWidget(
                      title: language.helpSupport,
                      iconData: 'images/customer_care.png',
                      onTap: () {
                        Navigator.pop(context);
                        launchScreen(context, HelpAndSupport(),
                            pageRouteAnimation: PageRouteAnimation.Slide);
                      }),
                  DrawerWidget(
                      title: language.setting,
                      iconData: ic_setting,
                      onTap: () {
                        Navigator.pop(context);
                        launchScreen(context, SettingScreen(),
                            pageRouteAnimation: PageRouteAnimation.Slide);
                      }),
                ],
              ),
            ),
            SizedBox(height: 16),
            Positioned(
                left: 0,
                right: 0,
                bottom: 20,
                child: Center(
                  child: Wrap(
                    children: [
                      AppButtonWidget(
                        color: primaryColor,
                        textStyle: boldTextStyle(color: Colors.white),
                        text: language.logOut,
                        onTap: () async {
                          await showConfirmDialogCustom(
                              _scaffoldKey.currentState!.context,
                              primaryColor: primaryColor,
                              dialogType: DialogType.CONFIRMATION,
                              title: language.areYouSureYouWantToLogoutThisApp,
                              positiveText: language.yes,
                              negativeText: language.no, onAccept: (v) async {
                            await appStore.setLoggedIn(true);
                            await Future.delayed(Duration(milliseconds: 500));
                            await logout();
                          });
                        },
                      ),
                    ],
                  ),
                ))
          ],
        ),
      ),
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () {
              launchScreen(context, NotificationScreen(),
                  pageRouteAnimation: PageRouteAnimation.Slide);
            },
            icon: Icon(Ionicons.notifications_outline),
          ),
        ],
      ),
      floatingActionButton: Align(
          alignment: Alignment(-0.8, 0.6),
          child: UnconstrainedBox(
            child: Container(
              color: primaryColor,
              padding: EdgeInsets.symmetric(vertical: 5,horizontal: 5),
              child: Row(
        children: [
              InkWell(
                onTap: () async {
                  await getCurrentUserLocation();
                  var currentZoomLevel = await _controller.getZoomLevel();

                  currentZoomLevel = currentZoomLevel + 2;
                  _controller.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        zoom: currentZoomLevel, target: sourceLocation!,
                      ),
                    ),
                  );
                },
                child:Icon(Icons.add,color: Colors.white,) ,
              ),const SizedBox(width:5,),InkWell(
                onTap: () async {
                  await getCurrentUserLocation();
                  var currentZoomLevel = await _controller.getZoomLevel();

                  currentZoomLevel = currentZoomLevel - 2;
                  _controller.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        zoom: currentZoomLevel, target: sourceLocation!,
                      ),
                    ),
                  );
                },
                child:Icon(Icons.remove,color: Colors.white,) ,
              )
        ],
      ),
            ),
          )),
      body: sourceLocation != null
          ? Stack(
              children: [
                GoogleMap(
                  onMapCreated: (controller) {
                    setState(() {
                      _controller=controller;
                    });
                  } ,
                  buildingsEnabled: true,
                  zoomGesturesEnabled: true,
                  tiltGesturesEnabled: false,
                  mapToolbarEnabled: true,
                  zoomControlsEnabled: true,
                  myLocationEnabled: true,
                  scrollGesturesEnabled: true,

                  //zoomGesturesEnabled: true,
                  myLocationButtonEnabled: true,
                  rotateGesturesEnabled: true,
                  compassEnabled: true,
                  //markers: Set<Marker>.of(markers),
                  markers: markers.toSet(),
                  polylines: _polyLines,
                  mapType: MapType.normal,
                  initialCameraPosition: CameraPosition(
                    target: sourceLocation!,
                    zoom: cameraZoom,
                    tilt: cameraTilt,
                    bearing: cameraBearing,
                  ),
                ),
                SlidingUpPanel(
                  padding: EdgeInsets.all(16),
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(defaultRadius),
                      topRight: Radius.circular(defaultRadius)),
                  backdropColor: primaryColor,
                  backdropTapClosesPanel: true,
                  minHeight: 150,
                  maxHeight: 150,
                  panel: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                  BorderRadius.circular(defaultRadius)),
                        ),
                      ),
                      Text(
                          language.whatWouldYouLikeToGo.capitalizeFirstLetter(),
                          style: primaryTextStyle()),
                      SizedBox(height: 16),
                      AppTextField(
                        autoFocus: false,
                        readOnly: true,
                        onTap: () async {
                          if (await checkPermission()) {
                            showModalBottomSheet(
                              isScrollControlled: true,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(defaultRadius),
                                    topRight: Radius.circular(defaultRadius)),
                              ),
                              context: context,
                              builder: (_) {
                                return RiderWidget(title: sourceLocationTitle);
                              },
                            );
                          }
                        },
                        textFieldType: TextFieldType.EMAIL,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Feather.search),
                          filled: true,
                          focusedBorder: OutlineInputBorder(
                              borderRadius: radius(),
                              borderSide: BorderSide(color: dividerColor)),
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          enabledBorder: OutlineInputBorder(
                              borderRadius: radius(),
                              borderSide: BorderSide(color: dividerColor)),
                          border: OutlineInputBorder(
                              borderRadius: radius(),
                              borderSide: BorderSide(color: dividerColor)),
                          hintText: language.enterYourDestination,
                        ),
                      ),
                      SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            )
          : loaderWidget(),
    );
  }
}


String aa='''<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"><title> Login Page </title><style>Body {font-family: Calibri, Helvetica, sans-serif;background-color: pink;}button {background-color: #4CAF50;width: 100%;color: orange;padding: 15px;margin: 10px 0px;border: none;cursor: pointer;}form {border: 3px solid #f1f1f1;}input[type=text], input[type=password] {width: 100%;margin: 8px 0;padding: 12px 20px;display: inline-block;border: 2px solid green;box-sizing: border-box;}button:hover {opacity: 0.7;}.cancelbtn {width: auto;padding: 10px 18px;margin: 10px 5px;}.container {padding: 25px;background-color: lightblue;}</style></head><body><center> <h1> Student Login Form </h1> </center><form><div class="container"><label>Username : </label><input type="text" placeholder="Enter Username" name="username" required><label>Password : </label><input type="password" placeholder="Enter Password" name="password" required><button type="submit">Login</button><input type="checkbox" checked="checked"> Remember me<button type="button" class="cancelbtn"> Cancel</button>Forgot <a href="#"> password? </a></div></form></body></html>''';

















