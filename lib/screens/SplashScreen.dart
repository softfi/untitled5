import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../main.dart';
import '../../utils/Extensions/app_common.dart';
import 'LoginScreen.dart';
import 'RiderDashBoardScreen.dart';

class SplashScreen extends StatefulWidget {
  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    //await determinePosition();
    await Future.delayed(Duration(seconds: 8));
    if (/*sharedPref.getBool(IS_FIRST_TIME) ?? true*/false) {
      //launchScreen(context, WalkThroughScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
    } else {
      if (appStore.isLoggedIn) {
        launchScreen(context, RiderDashBoardScreen(), pageRouteAnimation: PageRouteAnimation.Slide, isNewTask: true);
      } else {
        launchScreen(context, LoginScreen(), pageRouteAnimation: PageRouteAnimation.Slide, isNewTask: true);
      }
    }
  }

  @override
  void setState(fn) {
    if(mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            Image.asset("images/splash.gif", fit: BoxFit.contain, height: MediaQuery.of(context).size.height, width: MediaQuery.of(context).size.width),
            SizedBox(height: 16),
            //Text(language.appName, style: boldTextStyle(color: Colors.white, size: 22)),
          ],
        ),
      ),
    );
  }
}

Future<Position?> determinePosition() async {
  LocationPermission permission;
  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location Not Available');
    }
  } else {
    //throw Exception('Error');
  }
  return await Geolocator.getCurrentPosition();
}
