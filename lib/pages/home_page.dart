import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => new _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List jsonArray = [];
  Map<String, dynamic> newsJson = new Map<String, dynamic>();

  @override
  void initState() {
    super.initState();
    loadNewsSources();
  }

  loadNewsSources() async {
    String dataURL = "https://newsapi.org/v2/sources?language=en&country=us&apiKey=a30edf50cbbb48049945142f004c36c3";
    http.Response response = await http.get(dataURL);
    setState(() {
      newsJson = JSON.decode(response.body);
    });
  }

  buildList() {
    if (newsJson.length == 0) {
      return <Widget>[new CircularProgressIndicator()];
    } else {
      jsonArray = newsJson['sources'];
      List myList = <Widget>[];
      for (var i = 0; i < jsonArray.length; i++) {
        ListTile newsSource = new ListTile(
          title: new Text("${jsonArray[i]['name']}"),
          onTap: () => Navigator.pop(context)
        );

        myList.add(newsSource);
      }

      return myList;
    }
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(title: new Text("My News Reader")),
        drawer: new Drawer(
          child: new ListView(
            children: buildList(),
          ),
        ),
        body: new Center(
          child: new Text("HomePage"),
        ));
  }
}
