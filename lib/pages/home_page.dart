import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => new _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String appBarTitle = "News Reader";
  String newsSourceId = "";
  List newsSourcesArray = [];
  List newsStoriesArray = [];

  @override
  void initState() {
    super.initState();
    loadNewsSources();
  }

  loadNewsSources() async {
    String dataUrl =
        "https://newsapi.org/v2/sources?language=en&country=us&apiKey=a30edf50cbbb48049945142f004c36c3";

    http.Response response = await http.get(dataUrl);
    setState(() {
      Map<String, dynamic> newsSources = JSON.decode(response.body);
      newsSourcesArray = newsSources['sources'];
    });
  }

  buildListOfNewsSources() {
    if (newsSourcesArray.length == 0) {
      return new Center(child: new CircularProgressIndicator());
    } else {
      return new ListView(
          children: new List.generate(newsSourcesArray.length, (int index) {
        String newsSource = newsSourcesArray[index]['name'];
        return new ListTile(
            title: new Text(newsSource),
            onTap: () {
              Navigator.pop(context);
              newsSourceId = newsSourcesArray[index]['id'];
              appBarTitle = newsSourcesArray[index]['name'];
              newsStoriesArray.clear();
              loadNewsStories();
            });
      }));
    }
  }

  loadNewsStories() async {
    String dataUrl = "https://newsapi.org/v2/top-headlines?sources=" +
        newsSourceId +
        "&apiKey=a30edf50cbbb48049945142f004c36c3";
    http.Response response = await http.get(dataUrl);

    setState(() {
      Map<String, dynamic> newsStories = JSON.decode(response.body);
      newsStoriesArray = newsStories['articles'];
    });
  }

  buildListOfNewsStories() {
    if (newsStoriesArray.length == 0) {
      return new Center(child: new Text("<---- Select a news source!"));
    } else {
      return new Container(
        child: new ListView(
          children: new List.generate(newsStoriesArray.length, (int index) {
            String title = newsStoriesArray[index]['title'] == null ? ""  : newsStoriesArray[index]['title'];
            String newsText = newsStoriesArray[index]['description'] == null ? "" : newsStoriesArray[index]['description'];
            String url = newsStoriesArray[index]['url'] == null  ? ""  : newsStoriesArray[index]['url'];
            String imageUrl = newsStoriesArray[index]['urlToImage'] == null ? "" : newsStoriesArray[index]['urlToImage'];
            String dateTime = newsStoriesArray[index]['publishedAt'] == null ? ""  : newsStoriesArray[index]['publishedAt'];

            return new Card(
                child: new Column(children: <Widget>[
              new Image.network(imageUrl),
              new Text(title,
                  textAlign: TextAlign.left,
                  style: new TextStyle(
                      fontSize: 16.0, fontWeight: FontWeight.bold)),
              new Text(newsText),
              new Text(dateTime),
              new ButtonTheme.bar(
                  child: new ButtonBar(children: <Widget>[
                new FlatButton(
                  child: new Text("READ MORE"),
                  onPressed: () => _launchURL(url),
                )
              ]))
            ]));
          }),
        ),
      );
    }
  }

  _launchURL(String urlToOpen) async {
    String url = urlToOpen;
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      print('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(title: new Text(appBarTitle)),
        drawer: new Drawer(child: buildListOfNewsSources()),
        body: buildListOfNewsStories());
  }
}
