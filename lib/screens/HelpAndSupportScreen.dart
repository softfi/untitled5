import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:http/http.dart';

import '../utils/Colors.dart';
import '../utils/Extensions/app_common.dart';

class HelpAndSupport extends StatefulWidget {
  const HelpAndSupport({super.key});

  @override
  State<HelpAndSupport> createState() => _HelpAndSupportState();
}

class _HelpAndSupportState extends State<HelpAndSupport> {
  bool isLoading = false;
var data='';
  getHelpAndSupport() async {
    get(Uri.parse('https://app.sanjeevaniplus.com/api/help-support'))
        .then((value) {
      if (value.body != null) {
        setState(() {
          data=jsonDecode(value.body)[0];
        });
        print("this is the sdfsf sfsfsf n ${value.body}");
      }
    });
  }

  @override
  void initState() {
    getHelpAndSupport();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text('Help And Support', style: boldTextStyle(color: Colors.white)),
      ),
      body: isLoading?CircularProgressIndicator():SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: HtmlWidget(data
            ,
            onLoadingBuilder: (context, element, loadingProgress) =>
                CircularProgressIndicator(),
          ),
        ),
      ),/*Column(
        children: [
          supportItemWidget(Icons.health_and_safety_outlined, 'Safety', () {
            launchScreen(context,
                DetailScreenForHelpAndSupport(content: data, title: 'Safety'),
                pageRouteAnimation: PageRouteAnimation.Slide);
          }),
          supportItemWidget(
              Icons.my_library_books_outlined, 'All About Ambulance Services',
              () {
            launchScreen(
                context,
                DetailScreenForHelpAndSupport(
                    content: data, title: 'All About Ambulance Services'),
                pageRouteAnimation: PageRouteAnimation.Slide);
          }),
          supportItemWidget(
              Icons.integration_instructions_outlined, 'A Guide To Ambulance',
              () {
            launchScreen(
                context,
                DetailScreenForHelpAndSupport(
                    content: data, title: 'A Guide To Ambulance'),
                pageRouteAnimation: PageRouteAnimation.Slide);
          }),
          supportItemWidget(Icons.coronavirus_outlined, 'Covid 19', () {
            launchScreen(context,
                DetailScreenForHelpAndSupport(content: data, title: 'Covid 19'),
                pageRouteAnimation: PageRouteAnimation.Slide);
          }),
        ],
      ),*/
    );
  }

  Widget supportItemWidget(IconData icon, String title, Function() onTap,
      {bool isLast = false, IconData? suffixIcon}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          contentPadding: EdgeInsets.only(left: 16, right: 16),
          leading: Icon(icon, size: 25, color: primaryColor),
          title: Text(title, style: primaryTextStyle()),
          trailing: suffixIcon != null
              ? Icon(suffixIcon, color: Colors.green)
              : Icon(Icons.navigate_next, color: Colors.grey),
          onTap: onTap,
        ),
        if (!isLast) Divider(height: 0)
      ],
    );
  }
}

class DetailScreenForHelpAndSupport extends StatelessWidget {
  final String title;
  final String content;

  const DetailScreenForHelpAndSupport(
      {super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: boldTextStyle(color: Colors.white)),
      ),
      body: HtmlWidget(
        content,
        onLoadingBuilder: (context, element, loadingProgress) =>
            CircularProgressIndicator(),
      ),
    );
  }
}
