import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

import '../main.dart';
import '../model/LoginResponse.dart';
import '../network/RestApis.dart';
import '../screens/RiderDashBoardScreen.dart';
import '../utils/Constants.dart';
import '../utils/Extensions/StringExtensions.dart';
import '../utils/Extensions/app_common.dart';

FirebaseAuth _auth = FirebaseAuth.instance;

class AuthServices {
  Future<void> updateUserData(UserModel user) async {
    userService.updateDocument({
      'player_id': sharedPref.getString(PLAYER_ID),
      'updatedAt': Timestamp.now(),
    }, user.uid);
  }

  signUpWithEmailPassword(
    context, {
    String? name,
    String? email,
    String? password,
    String? mobileNumber,
    String? fName,
    String? lName,
    String? userName,
    bool socialLoginName = false,
    String? userType,
    String? uID,
    bool isOtp = false,
    bool isExist = true,
    String? gender,
  }) async {
    debugPrint("==========================>(^^)${email} ${password}");
    UserCredential? userCredential = await _auth.createUserWithEmailAndPassword(
        email: email!, password: password!);
    // _auth.getFirebaseAuthSettings().setAppVerificationDisabledForTesting(true);
    debugPrint("================3625432634)${userCredential.user}");
    if (userCredential.user != null) {
      User currentUser = userCredential.user!;
      UserModel userModel = UserModel();

      /// Create user
      userModel.uid = currentUser.uid;
      userModel.email = currentUser.email;
      userModel.contactNumber = mobileNumber;
      userModel.username = userName;
      userModel.userType = userType;
      userModel.displayName = fName.validate() + " " + lName.validate();
      userModel.firstName = fName;
      userModel.lastName = lName;
      userModel.createdAt = Timestamp.now().toDate().toString();
      userModel.updatedAt = Timestamp.now().toDate().toString();
      userModel.playerId = sharedPref.getString(PLAYER_ID);
      sharedPref.setString(UID, userCredential.user!.uid.validate());
      await userService
          .addDocumentWithCustomId(currentUser.uid, userModel.toJson())
          .then((value) async {
        Map req = {
          'first_name': fName,
          'last_name': lName,
          'username': userName,
          'email': email,
          "user_type": "rider",
          "contact_number": mobileNumber,
          'password': password,
          "player_id": sharedPref.getString(PLAYER_ID).validate(),
          "uid": userModel.uid,
          "gender": gender,
          if (socialLoginName) 'login_type': 'mobile',
        };
        debugPrint("body of registration ${req.toString()}");
        log(req);
        if (!isExist) {
          updateProfileUid();
          launchScreen(context, RiderDashBoardScreen(),
              isNewTask: true, pageRouteAnimation: PageRouteAnimation.Slide);
        } else {
          await signUpApi(req).then((value) {
            debugPrint("value of registration $value");
            launchScreen(context, RiderDashBoardScreen(),
                isNewTask: true, pageRouteAnimation: PageRouteAnimation.Slide);
          }).catchError((error) {
            debugPrint("error of registration $error");
            toast(error.toString());
          });
          appStore.setLoading(false);
        }
        return userModel.uid;
      }).catchError((e) {
        appStore.setLoading(false);
        toast(e.toString());
      });
    }
  }

  Future<void> signInWithEmailPassword(context,
      {required String email, required String password}) async {
    await _auth
        .signInWithEmailAndPassword(email: email, password: password)
        .then((value) async {
      appStore.setLoading(true);
      final User user = value.user!;
      UserModel userModel = await userService.getUser(email: user.email);
      //await updateUserData(userModel);

      appStore.setLoading(true);
      //Login Details to SharedPreferences
      sharedPref.setString(UID, userModel.uid.validate());
      sharedPref.setString(USER_EMAIL, userModel.email.validate());
      sharedPref.setBool(IS_LOGGED_IN, true);

      //Login Details to AppStore
      appStore.setUserEmail(userModel.email.validate());
      appStore.setUId(userModel.uid.validate());

      //
    }).catchError((e) {
      toast(e.toString());
      log(e.toString());
    });
  }

  Future<void> loginFromFirebaseUser(User currentUser,
      {LoginResponse? loginDetail,
      String? fullName,
      String? fName,
      String? lName}) async {
    UserModel userModel = UserModel();

    if (await userService.isUserExist(loginDetail!.data!.email)) {
      ///Return user data
      await userService.userByEmail(loginDetail.data!.email).then((user) async {
        userModel = user;
        appStore.setUserEmail(userModel.email.validate());
        appStore.setUId(userModel.uid.validate());

        // await updateUserData(user);
      }).catchError((e) {
        log(e);
        throw e;
      });
    } else {
      /// Create user
      userModel.uid = currentUser.uid.validate();
      userModel.id = loginDetail.data!.id;
      userModel.email = loginDetail.data!.email.validate();
      userModel.username = loginDetail.data!.username.validate();
      userModel.contactNumber = loginDetail.data!.contactNumber.validate();
      userModel.username = loginDetail.data!.username.validate();
      userModel.email = loginDetail.data!.email.validate();

      if (Platform.isIOS) {
        userModel.username = fullName;
      } else {
        userModel.username = loginDetail.data!.username.validate();
      }

      userModel.contactNumber = loginDetail.data!.contactNumber.validate();
      userModel.profileImage = loginDetail.data!.profileImage.validate();
      userModel.playerId = sharedPref.getString(PLAYER_ID);

      sharedPref.setString(UID, currentUser.uid.validate());
      log(sharedPref.getString(UID));
      sharedPref.setString(USER_EMAIL, userModel.email.validate());
      sharedPref.setBool(IS_LOGGED_IN, true);

      log(userModel.toJson());

      await userService
          .addDocumentWithCustomId(currentUser.uid, userModel.toJson())
          .then((value) {
        //
      }).catchError((e) {
        throw e;
      });
    }
  }

  Future deleteUserFirebase() async {
    if (FirebaseAuth.instance.currentUser != null) {
      FirebaseAuth.instance.currentUser!.delete();
      await FirebaseAuth.instance.signOut();
    }
  }
}
