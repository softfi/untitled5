import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../network/RestApis.dart';
import '../screens/RiderDashBoardScreen.dart';
import '../utils/Colors.dart';
import '../utils/Constants.dart';
import '../utils/Extensions/AppButtonWidget.dart';
import '../utils/Extensions/ConformationDialog.dart';
import '../utils/Extensions/app_common.dart';

class BookingWidget extends StatefulWidget {
  final bool isLast;
  final int? id;

  BookingWidget({required this.id, this.isLast = false});
  @override
  BookingWidgetState createState() => BookingWidgetState();
}

class BookingWidgetState extends State<BookingWidget> {
  final int timerMaxSeconds = appStore.rideMinutes != null
      ? int.parse(appStore.rideMinutes!) * 60
      : 5 * 60;

  int currentSeconds = 0;
  int duration = 0;
  int count = 0;
  Timer? timer;
  GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  String get timerText =>
      '${((duration - currentSeconds) ~/ 60).toString().padLeft(2, '0')}: ${((duration - currentSeconds) % 60).toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    print(REMAINING_TIME);
    print(IS_TIME);
    if (sharedPref.getString(IS_TIME) == null) {
      print("working finedffdd ${widget.id}");
      duration = timerMaxSeconds;
      startTimeout();
      sharedPref.setString(IS_TIME,
          DateTime.now().add(Duration(seconds: timerMaxSeconds)).toString());
      sharedPref.setString(REMAINING_TIME, timerMaxSeconds.toString());
    } else {
      print("working fineAAAAAAA");
      duration = DateTime.parse(sharedPref.getString(IS_TIME)!)
          .difference(DateTime.now())
          .inSeconds;
      if (duration > 0) {
        startTimeout();
      } else {
        sharedPref.remove(IS_TIME);
        duration = timerMaxSeconds;
        setState(() {});
      }
    }
  }

  startTimeout() {
    var duration2 = Duration(seconds: 1);
    timer = Timer.periodic(duration2, (timer) {
      setState(
        () {
          currentSeconds = timer.tick;
          count++;
          print("working fine $count");
          if (count >= 60) {
            int data = int.parse(sharedPref.getString(REMAINING_TIME)!);
            data = data - count;
            Map req = {
              'max_time_for_find_driver_for_ride_request': data,
            };
            rideRequestUpdate(request: req, rideId: widget.id).then((value) {
              //
            }).catchError((error) {
              log(error.toString());
            });
            sharedPref.setString(REMAINING_TIME, data.toString());
            count = 0;
          }
          if (timer.tick >= duration) {
            Map req = {
              'status': CANCELED,
              'cancel_by': AUTO,
            };
            rideRequestUpdate(request: req, rideId: widget.id).then((value) {
              launchScreen(context, RiderDashBoardScreen());
              timer.cancel();
              sharedPref.remove(REMAINING_TIME);
              sharedPref.remove(IS_TIME);
            }).catchError((error) {
              log(error.toString());
            });
          }
        },
      );
    });
  }

  Future<void> cancelRequest() async {
    Map req = {
      "id": widget.id,
      "cancel_by": 'rider',
      "status": CANCELED,
    };

    debugPrint("this is body of cancel ride ${req.toString}");
    debugPrint("cancel ride ID ${widget.id}");
    await rideRequestUpdate(request: req, rideId: widget.id)
        .then((value) async {
      if (widget.isLast) {
        debugPrint("ejrkyhtgiureyiur $value");

        launchScreen(context, RiderDashBoardScreen(), isNewTask: true);
        //Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => RiderDashBoardScreen(),), (route) => false);
      } else {
        Navigator.pop(context);
        Navigator.pop(context);
      }

      toast(value.message);
    }).catchError((error) {
      log(error.toString());
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(language.lookingForNearbyDrivers, style: boldTextStyle()),
              Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(color: primaryColor),
                child:
                    Text(timerText, style: boldTextStyle(color: Colors.white)),
              )
            ],
          ),
          // SizedBox(height: 16),
          Image.asset('images/ambulance.gif',
              height: 120, width: MediaQuery.of(context).size.width),
          //Lottie.asset('images/booking.json', height: 100, width: MediaQuery.of(context).size.width, fit: BoxFit.contain),
          SizedBox(height: 20),
          Text(language.weAreLookingForNearDriversAcceptsYourRide,
              style: primaryTextStyle(), textAlign: TextAlign.center),
          SizedBox(height: 20),
          AppButtonWidget(
            width: MediaQuery.of(context).size.width,
            color: primaryColor,
            text: language.cancel,
            textStyle: boldTextStyle(color: Colors.white),
            onTap: () {
              showConfirmDialogCustom(context,
                  primaryColor: primaryColor,
                  title: language.areYouSureYouWantToCancelThisRide,
                  dialogType: DialogType.CONFIRMATION, onAccept: (_) {
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
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    child: ListView(
                                      children: [
                                        Padding(
                                          padding:
                                          const EdgeInsets.symmetric(horizontal: 20),
                                          child: Row(
                                            mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                "Cancel trip?",
                                                style: TextStyle(
                                                    color: Theme.of(context).primaryColor,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: Text(
                                                  "Skip",
                                                  style: TextStyle(
                                                      color:
                                                      Theme.of(context).primaryColor,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold),
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
                                          const EdgeInsets.symmetric(horizontal: 20),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const SizedBox(
                                                height: 20,
                                              ),
                                              Text(
                                                "Why do you want to cancel?",
                                                style: TextStyle(
                                                    color: Theme.of(context).primaryColor,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold),
                                              ),
                                              const SizedBox(
                                                height: 5,
                                              ),
                                              Text(
                                                "Optional",
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.normal),
                                              ),
                                              InkWell(
                                                onTap: () => st((){
                                                  index=1;
                                                }),
                                                child: _rowBuilder(
                                                    text: "Requested wrong vehicle",
                                                    value: index==1),
                                              ),
                                              InkWell(
                                                onTap: () => st((){
                                                  index=2;
                                                }),
                                                child: _rowBuilder(
                                                    text: "Selected wrong drop-off",
                                                    value: index==2),
                                              ),
                                              InkWell(
                                                onTap: () => st((){
                                                  index=3;
                                                }),
                                                child: _rowBuilder(
                                                    text: "Selected wrong pick-up",
                                                    value: index==3),
                                              ),
                                              InkWell(
                                                onTap: () => st((){
                                                  index=4;
                                                }),
                                                child: _rowBuilder(
                                                    text: "Waiting time was too long",
                                                    value: index==4),
                                              ),
                                              InkWell(
                                                onTap: () => st((){
                                                  index=5;
                                                }),
                                                child: _rowBuilder(
                                                    text: "Requested by accident",
                                                    value: index==5),
                                              ),
                                              InkWell(
                                                  onTap: () => st((){
                                                    index=6;
                                                  }),child: _rowBuilder(text: "Others", value: index==6)),
                                              SizedBox(
                                                  width:
                                                  MediaQuery.of(context).size.width,
                                                  child: ElevatedButton(
                                                      onPressed: (){
                                                        //Navigator.pop(context);
                                                        cancelRequest();
                                                        sharedPref.remove(REMAINING_TIME);
                                                        sharedPref.remove(IS_TIME);
                                                      },
                                                      child: Text("Submit")))
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
                // cancelRequest();

              });
            },
          )
        ],
      ),
    );
  }

  Widget _rowBuilder(
      {required bool value, required String text}) =>

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
                fillColor: MaterialStateColor.resolveWith((states) => Theme.of(context).primaryColor),
                activeColor: Theme.of(context).primaryColor,
              ),
            ),
          ),
          Text(text)
        ],
      );
  int index=-1;
}
