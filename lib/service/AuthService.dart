import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../components/OTPDialog.dart';
import '../main.dart';
import '../network/RestApis.dart';
import '../screens/EditProfileScreen.dart';
import '../screens/RiderDashBoardScreen.dart';
import '../utils/Constants.dart';
import '../utils/Extensions/StringExtensions.dart';
import '../utils/Extensions/app_common.dart';
import 'AuthService1.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;

Future<void> loginWithOTP(BuildContext context, String phoneNumber) async {
  appStore.setLoading(true);
  return await _auth.verifyPhoneNumber(
    phoneNumber: phoneNumber,
    verificationCompleted: (PhoneAuthCredential credential) async {},
    verificationFailed: (FirebaseAuthException e) {
      if (e.code == 'invalid-phone-number') {
        toast('The provided phone number is not valid.');
        throw 'The provided phone number is not valid.';
      } else {
        log('**************${e.toString()}');
        toast(e.toString());
        throw e.toString();
      }
    },
    codeSent: (String verificationId, int? resendToken) async {
      Navigator.pop(context);
      appStore.setLoading(false);
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
            content: OTPDialog(
                verificationId: verificationId,
                isCodeSent: true,
                phoneNumber: phoneNumber)),
        barrierDismissible: false,
      );
    },
    codeAutoRetrievalTimeout: (String verificationId) {
      //
    },
  );
}

class GoogleAuthServices {
  final GoogleSignIn googleSignIn = GoogleSignIn();
  AuthServices authService = AuthServices();

  Future<void> signInWithGoogle(BuildContext context) async {
    GoogleSignInAccount? googleSignInAccount = await googleSignIn.signIn();

    if (googleSignInAccount != null) {
      //Authentication
      final GoogleSignInAuthentication googleSignInAuthentication =
          await googleSignInAccount.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleSignInAuthentication.accessToken,
        idToken: googleSignInAuthentication.idToken,
      );

      final UserCredential authResult =
          await _auth.signInWithCredential(credential);
      final User user = authResult.user!;

      assert(!user.isAnonymous);

      final User currentUser = _auth.currentUser!;
      assert(user.uid == currentUser.uid);
      googleSignIn.signOut();
      String firstName = '';
      String lastName = '';
      if (currentUser.displayName.validate().split(' ').length >= 1)
        firstName = currentUser.displayName.splitBefore(' ');
      if (currentUser.displayName.validate().split(' ').length >= 2)
        lastName = currentUser.displayName.splitAfter(' ');
      debugPrint("sjdhfjhsdgfjhdsf ${(firstName + lastName).toLowerCase()}");
      Map req = {
        "email": currentUser.email,
        "login_type": LoginTypeGoogle,
        "user_type": RIDER,
        "first_name": firstName,
        "last_name": lastName,
        "username": (firstName + lastName).toLowerCase(),
        'accessToken': googleSignInAuthentication.accessToken,
        if (!currentUser.phoneNumber.isEmptyOrNull)
          'contact_number': currentUser.phoneNumber.validate(),
      };

      print("data->" + currentUser.photoURL.toString());
      await logInApi(req, isSocialLogin: true).then((value) async {
        Navigator.pop(context);
        sharedPref.setString(UID, currentUser.uid);
        await appStore.setUserProfile(currentUser.photoURL.toString());
        await sharedPref.setString(
            USER_PROFILE_PHOTO, currentUser.photoURL.toString());
        if (value.data!.contactNumber.isEmptyOrNull) {
          launchScreen(context, EditProfileScreen(isGoogle: true),
              isNewTask: true, pageRouteAnimation: PageRouteAnimation.Slide);
        } else {
          launchScreen(context, RiderDashBoardScreen(),
              isNewTask: true, pageRouteAnimation: PageRouteAnimation.Slide);
        }
      }).catchError((e) {
        log(e.toString());
        throw e;
      });
    } else {
      throw errorSomethingWentWrong;
    }
  }
}

class AppleAuthServices {
  AppleAuthServices();

  Future<void> signInWithApple(BuildContext context) async {
    try {
      if (true) {
        final _firebaseAuth = FirebaseAuth.instance;
        String generateNonce([int length = 32]) {
          final charset =
              '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
          final random = Random.secure();
          return List.generate(
              length, (_) => charset[random.nextInt(charset.length)]).join();
        }

        String sha256ofString(String input) {
          final bytes = utf8.encode(input);
          final digest = sha256.convert(bytes);

          return digest.toString();
        }

        final rawNonce = generateNonce();
        final nonce = sha256ofString(rawNonce);
        final credential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: nonce,
        ).catchError((e) {
          throw errorSomethingWentWrong;
        });
        final oauthCredential = OAuthProvider("apple.com").credential(
          idToken: credential.identityToken,
          rawNonce: rawNonce,
        );
        final UserCredential authResult = await _firebaseAuth
            .signInWithCredential(oauthCredential)
            .onError((dynamic error, stackTrace) {
          throw Future.error(error);
        }).catchError((_) {});
        print(authResult.additionalUserInfo!.profile.toString() +
            "0990990909909");

        Map req = {
          "email": authResult.additionalUserInfo?.profile?["email"],
          "login_type": LoginTypeApple,
          "user_type": RIDER,
          "first_name": credential.givenName ?? "",
          "last_name": credential.familyName ?? "",
          "username":
              (credential.givenName ?? "" + (credential.familyName ?? ""))
                  .toLowerCase(),
          'accessToken': credential.identityToken ?? "",
          // if (!currentUser.phoneNumber.isEmptyOrNull)
          //   'contact_number': currentUser.phoneNumber.validate(),
        };

        try {
          await logInApi(req, isSocialLogin: true).then((value) async {
            Navigator.pop(context);
            debugPrint(
                "value.data?.id.toString() ${value.data?.id.toString()}");
            await sharedPref.setString(UID, value.data?.id.toString() ?? "");
            await appStore.setUserProfile("");
            await sharedPref.setString(USER_PROFILE_PHOTO, "");
            if (value.data!.contactNumber.isEmptyOrNull) {
              launchScreen(context, EditProfileScreen(isGoogle: true),
                  isNewTask: true,
                  pageRouteAnimation: PageRouteAnimation.Slide);
            } else {
              launchScreen(context, RiderDashBoardScreen(),
                  isNewTask: true,
                  pageRouteAnimation: PageRouteAnimation.Slide);
            }
          }).catchError((e) {
            log(e.toString());
            throw e;
          });
        } catch (_) {
          throw errorSomethingWentWrong;
        }
      }
    } catch (e) {
      print(
          "Exception - login_screen.dart - _signinWithApple():" + e.toString());
    }
  }
}
