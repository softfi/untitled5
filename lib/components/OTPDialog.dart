import 'package:country_code_picker/country_code_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:otp_text_field/otp_field.dart';
import 'package:otp_text_field/style.dart';

import '../../main.dart';
import '../../network/RestApis.dart';
import '../screens/RegisterScreen.dart';
import '../screens/RiderDashBoardScreen.dart';
import '../service/AuthService.dart';
import '../utils/Colors.dart';
import '../utils/Common.dart';
import '../utils/Constants.dart';
import '../utils/Extensions/AppButtonWidget.dart';
import '../utils/Extensions/StringExtensions.dart';
import '../utils/Extensions/app_common.dart';
import '../utils/Extensions/app_textfield.dart';

class OTPDialog extends StatefulWidget {
  final String? verificationId;
  final String? phoneNumber;
  final bool? isCodeSent;
  final PhoneAuthCredential? credential;

  OTPDialog(
      {this.verificationId,
      this.isCodeSent,
      this.phoneNumber,
      this.credential});

  @override
  OTPDialogState createState() => OTPDialogState();
}

class OTPDialogState extends State<OTPDialog> {
  OtpFieldController otpController = OtpFieldController();
  TextEditingController phoneController = TextEditingController();

  String verId = '';
  String otpCode = '+91';

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    //
  }

  Future<void> submit() async {
    appStore.setLoading(true);

    AuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId!, smsCode: verId.validate());

    print("Number->" + otpCode);
    print("Number->" + widget.phoneNumber.toString());

    await FirebaseAuth.instance
        .signInWithCredential(credential)
        .then((result) async {
      Map req = {
        "email": "",
        "login_type": "mobile",
        "user_type": "rider",
        "username": widget.phoneNumber!.replaceAll('$otpCode', ''),
        'accessToken': widget.phoneNumber!.replaceAll('$otpCode', ''),
        'contact_number': widget.phoneNumber,
      };

      log(req);
      await logInApi(req, isSocialLogin: true).then((value) async {
        appStore.setLoading(false);
        if (value.data == null) {
          appStore.setLoading(false);
          Navigator.pop(context);
          launchScreen(
              context,
              RegisterScreen(
                  countryCode: otpCode,
                  userName: widget.phoneNumber!.replaceAll('$otpCode', ''),
                  socialLogin: true));
        } else {
          appStore.setLoading(false);
          Navigator.pop(context);
          sharedPref.setString(UID, widget.phoneNumber ?? "");
          launchScreen(context, RiderDashBoardScreen(), isNewTask: true);
        }
      }).catchError((e) {
        appStore.setLoading(false);
        log(e.toString());
      });
    }).catchError((e) {
      appStore.setLoading(false);
      toast(e.toString());
    });
  }

  Future<void> sendOTP() async {
    appStore.setLoading(true);

    String number = '$otpCode${phoneController.text.trim()}';

    log('$otpCode${phoneController.text.trim()}');

    await loginWithOTP(context, number).then((value) {
      //
    }).catchError((e) {
      appStore.setLoading(false);

      toast(e.toString());
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isCodeSent.validate()) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(language.signInUsingYourMobileNumber,
                  style: boldTextStyle()),
              IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: Icon(Icons.close_sharp),
              )
            ],
          ),
          SizedBox(height: 30),
          AppTextField(
            controller: phoneController,
            textFieldType: TextFieldType.PHONE,
            decoration: inputDecoration(
              context,
              label: language.phoneNumber,
              prefixIcon: IntrinsicHeight(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CountryCodePicker(
                      padding: EdgeInsets.zero,
                      initialSelection: otpCode,
                      showCountryOnly: false,
                      dialogSize: Size(MediaQuery.of(context).size.width - 60,
                          MediaQuery.of(context).size.height * 0.6),
                      showFlag: true,
                      showFlagDialog: true,
                      showOnlyCountryWhenClosed: false,
                      alignLeft: false,
                      textStyle: primaryTextStyle(),
                      dialogBackgroundColor: Theme.of(context).cardColor,
                      barrierColor: Colors.black12,
                      dialogTextStyle: primaryTextStyle(),
                      searchDecoration: InputDecoration(
                        iconColor: Theme.of(context).dividerColor,
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context).dividerColor)),
                        focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: primaryColor)),
                      ),
                      searchStyle: primaryTextStyle(),
                      onInit: (c) {
                        otpCode = c!.dialCode!;
                      },
                      onChanged: (c) {
                        otpCode = c.dialCode!;
                      },
                    ),
                    VerticalDivider(color: Colors.grey.withOpacity(0.5)),
                  ],
                ),
              ),
            ),
            validator: (value) {
              if (value!.trim().isEmpty) return language.thisFieldRequired;
              if (value.trim().length < 10 || value.trim().length > 14)
                return language.contactLength;
              return null;
            },
          ),
          SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              AppButtonWidget(
                onTap: () {
                  if (phoneController.text.trim().isEmpty) {
                    return toast(language.thisFieldRequired);
                  } else {
                    hideKeyboard(context);
                    sendOTP();
                  }
                },
                text: language.sendOTP,
                color: primaryColor,
                textStyle: boldTextStyle(color: Colors.white),
                width: MediaQuery.of(context).size.width,
              ),
              Positioned(
                child: Observer(builder: (context) {
                  return Visibility(
                    visible: appStore.isLoading,
                    child: loaderWidget(),
                  );
                }),
              ),
            ],
          )
        ],
      );
    } else {
      return Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.message, color: primaryColor, size: 50),
              SizedBox(height: 16),
              Text(language.otpVerification, style: boldTextStyle(size: 18)),
              SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  Text(language.enterTheCodeSendTo,
                      style: secondaryTextStyle(size: 16)),
                  SizedBox(width: 4),
                  Text(widget.phoneNumber.validate(), style: boldTextStyle()),
                ],
              ),
              SizedBox(height: 16),
              OTPTextField(
                controller: otpController,
                length: 6,
                width: MediaQuery.of(context).size.width,
                fieldWidth: 35,
                style: primaryTextStyle(),
                textFieldAlignment: MainAxisAlignment.spaceAround,
                fieldStyle: FieldStyle.box,
                onChanged: (s) {
                  verId = s;
                },
                onCompleted: (pin) {
                  verId = pin;
                  submit();
                },
              ),
            ],
          ),
          Observer(
            builder: (context) => Positioned.fill(
              child: Visibility(
                visible: appStore.isLoading,
                child: loaderWidget(),
              ),
            ),
          ),
        ],
      );
    }
  }
}