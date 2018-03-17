import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share/share.dart' as sharing;

final ThemeData _kGalleryDarkTheme = new ThemeData(
  brightness: Brightness.dark,
  primarySwatch: Colors.blue,
);

final ThemeData _kGalleryLightTheme = new ThemeData(
  brightness: Brightness.light,
  primarySwatch: Colors.blue,
);

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => new _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final String FAVORITE_NEWS_SOURCES = "FAVORITE_NEWS_SOURCES";
  final String USE_DARK_THEME = "USE_DARK_THEME";

  bool useDarkTheme = false;
  String appBarTitle = "News Reader";
  String newsSourceId = "";
  List newsSourcesArray = [];
  List newsStoriesArray = [];
  List favoriteNewsSources = [];
  String _selectedNewsSource =
      ""; // used to highlight currently selected news source listTile
  GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      new GlobalKey<RefreshIndicatorState>();
  ScrollController _scrollController = new ScrollController();
  SharedPreferences prefs = null;

  @override
  void initState() {
    super.initState();

//    getFavoriteNewsSourcesFromDisk()
//        .then((asd) => loadNewsSources())
//        .then((asd) => sortNewsSourcesArray())
//        .then((asd) => getThemeSelectionFromDisk());

    initSharedPreferences()
        .then((asd) => getFavoriteNewsSourcesFromDisk())
        .then((asd) => loadNewsSources())
        .then((asd) => sortNewsSourcesArray())
        .then((asd) => getThemeSelectionFromDisk());
  }

  /*
   * HTTP methods begin
   */

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
      return new Drawer(
          child: new Center(child: new CircularProgressIndicator()));
    } else {
      return new Drawer(
          child: new Scrollbar(
              child: new ListView(
                  children:
                      new List.generate(newsSourcesArray.length, (int index) {
        String newsSource = newsSourcesArray[index]['name'];
        return new ListTile(
            leading: new Container(
                height: 75.0,
                width: 100.0,
                child: new InkWell(
                    child: favoriteNewsSources.contains(newsSource)
                        ? const Icon(Icons.favorite)
                        : const Icon(Icons.favorite_border),
                    onTap: () {
                      setState(() {
                        if (favoriteNewsSources.contains(newsSource))
                          favoriteNewsSources.remove(newsSource);
                        else
                          favoriteNewsSources.add(newsSource);

                        saveFavoriteNewsSourcesToDisk();
                        sortNewsSourcesArray();
                      });
                    })),
            title: new Text(newsSource, style: new TextStyle(fontSize: 20.0)),
            selected: _selectedNewsSource == newsSourcesArray[index]['name'],
            onTap: () {
              if (_scrollController.hasClients) _scrollController.jumpTo(0.0);
              Navigator.pop(context);
              newsSourceId = newsSourcesArray[index]['id'];
              appBarTitle = newsSourcesArray[index]['name'];
              _selectedNewsSource = newsSourcesArray[index]['name'];
              newsStoriesArray.clear();
              loadNewsStories();
            });
      }))));
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

  loadNewsStoriesFromSearch(String keyWord) async {
    // get today's date
    DateTime dateTimeObj = new DateTime.now();
    String today = formatDateForSearchQuery(dateTimeObj);

    // get yesterday's date
    dateTimeObj = dateTimeObj.add(new Duration(days: -1));
    String yesterday = formatDateForSearchQuery(dateTimeObj);

    String searchUrl = "https://newsapi.org/v2/everything?q=" +
        keyWord +
        "&from=" +
        yesterday +
        "&to=" +
        today +
        "&language=en&sortBy=publishedAt&apiKey=a30edf50cbbb48049945142f004c36c3";

    http.Response response = await http.get(searchUrl);

    setState(() {
      Map<String, dynamic> newsStories = JSON.decode(response.body);
      newsStoriesArray = newsStories['articles'];
    });
  }

  /*
   * UI methods begin
   */

  buildListOfNewsStories() {
    if (newsStoriesArray == null || newsStoriesArray.length == 0) {
      double screenWidth = MediaQuery.of(context).size.width;
      return new Row(
        children: <Widget>[
          new Expanded(
              child: new InkWell(
                  onTap: () => _scaffoldKey.currentState.openDrawer(),
                  child: new Center(
                      child: new Material(
                          elevation: 15.0,
                          shape: new CircleBorder(),
                          child: new CircleAvatar(
                            radius: screenWidth / 3,
                            child: new Icon(Icons.touch_app,
                                size: screenWidth / 3),
                          )))))
        ],
      );
    } else {
      return new Scrollbar(
        child: new RefreshIndicator(
            onRefresh: () => refreshNewsStories(),
            child: new ListView(
              controller: _scrollController,
              children: new List.generate(newsStoriesArray.length, (int index) {
                String title = newsStoriesArray[index]['title'] == null
                    ? ""
                    : newsStoriesArray[index]['title'];
                String newsText = newsStoriesArray[index]['description'] == null
                    ? ""
                    : newsStoriesArray[index]['description'];
                String url = newsStoriesArray[index]['url'] == null
                    ? ""
                    : newsStoriesArray[index]['url'];
                String imageUrl = newsStoriesArray[index]['urlToImage'] == null
                    ? ""
                    : newsStoriesArray[index]['urlToImage'];
                String dateTime = newsStoriesArray[index]['publishedAt'] == null
                    ? ""
                    : newsStoriesArray[index]['publishedAt'];

                String formattedDate = formatDateForUi(dateTime);

                return new Padding(
                    padding: new EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                    child: new InkWell(
                        onTap: () => _launchURL(url),
                        child: new Card(
                            elevation: 5.0,
                            child: new Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  showImage(imageUrl),
                                  new Padding(
                                    padding: new EdgeInsets.fromLTRB(
                                        8.0, 8.0, 8.0, 8.0),
                                    child: new Text(title,
                                        textAlign: TextAlign.left,
                                        style: new TextStyle(
                                            fontSize: 26.0,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  new Padding(
                                    padding: new EdgeInsets.fromLTRB(
                                        16.0, 8.0, 16.0, 8.0),
                                    child: new Text(newsText,
                                        style: new TextStyle(fontSize: 16.0)),
                                  ),
                                  new Padding(
                                      padding: new EdgeInsets.fromLTRB(
                                          16.0, 16.0, 16.0, 8.0),
                                      child: new Row(
                                        children: <Widget>[
                                          new Expanded(
                                            child: new Text(formattedDate,
                                                style: new TextStyle(
                                                    fontStyle:
                                                        FontStyle.italic)),
                                          ),
                                          new IconButton(
                                              icon: new Icon(
                                                Icons.share,
                                                color: Colors.blue,
                                              ),
                                              padding: new EdgeInsets.fromLTRB(
                                                  0.0, 0.0, 16.0, 0.0),
                                              iconSize: 32.0,
                                              onPressed: () => sharing.share(
                                                  '"' +
                                                      title +
                                                      '"' +
                                                      " " +
                                                      url)),
                                          new Text("READ MORE",
                                              style: new TextStyle(
                                                  fontSize: 16.0,
                                                  color: Colors.blue,
                                                  fontWeight: FontWeight.bold))
                                        ],
                                      ))
                                ]))));
              }),
            )),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return new Theme(
        data: useDarkTheme ? _kGalleryDarkTheme : _kGalleryLightTheme,
        child: new Scaffold(
            key: _scaffoldKey,
            appBar: buildAppBar(),
            drawer: buildListOfNewsSources(),
            body: buildListOfNewsStories()));
  }

  buildAppBar() {
    return new AppBar(
      title: new Text(appBarTitle),
      actions: <Widget>[
        new IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => showSearchDialog()),
        setIconForTheme(),
        new Switch(
          value: useDarkTheme,
          onChanged: (bool value) {
            saveThemeSelectionToDisk(value);
            setState(() {
              useDarkTheme = value;
            });
          },
        )
      ],
    );
  }

  Future<Null> showSearchDialog() async {
    TextEditingController _textFieldController = new TextEditingController();
    double screenWidth = MediaQuery.of(context).size.width;
    return showDialog<Null>(
      context: context,
      barrierDismissible: true,
      child: new Theme(
          data: useDarkTheme ? _kGalleryDarkTheme : _kGalleryLightTheme,
          child: new AlertDialog(
            title: new Text('Search For News Articles...'),
            content: new SingleChildScrollView(
              child: new ListBody(
                children: <Widget>[
                  new SizedBox(
                    width: screenWidth * 0.8,
                    height: 50.0,
                    child: new TextField(
                      controller: _textFieldController,
                      maxLength: 50,
                      maxLengthEnforced: true,
                      decoration:
                          new InputDecoration(icon: const Icon(Icons.search)),
                      onSubmitted: (asd) =>
                          beginNewsSearch(_textFieldController.text),
                    ),
                  )
                ],
              ),
            ),
            actions: <Widget>[
              new FlatButton(
                child: new Text('CLOSE'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              new FlatButton(
                child: new Text('SEARCH'),
                onPressed: () {
                  beginNewsSearch(_textFieldController.text);
                },
              ),
            ],
          )),
    );
  }

  /*
  * HELPER FUNCTIONS BELOW...
  */

  beginNewsSearch(String keyword) {
    newsStoriesArray.clear();

    if (keyword.length > 0)
      appBarTitle = "'" + keyword + "'" + " results";
    else
      appBarTitle = "News Reader";
    
    loadNewsStoriesFromSearch(keyword);
    Navigator.of(context).pop();
  }

  setIconForTheme() {
    if (useDarkTheme)
      return new Icon(Icons.wb_sunny);
    else
      return new Icon(Icons.brightness_2);
  }

  String formatDateForUi(String dateTime) {
    String formattedDate = "";

    if (dateTime != "") {
      String newDateTime = dateTime.substring(0, 19) + "Z";
      DateTime dtObj = DateTime.parse(newDateTime);
      DateTime localDtObj = dtObj.toLocal();
      DateFormat formatter = new DateFormat('MMMM d. yyyy h:mm a');
      formattedDate = formatter.format(localDtObj);
    }
    return formattedDate;
  }

  String formatDateForSearchQuery(DateTime dateTimeObj) {
    DateFormat formatter = new DateFormat('yyyy-MM-dd');
    return formatter.format(dateTimeObj);
  }

  _launchURL(String urlToOpen) async {
    String url = urlToOpen;
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      print('Could not launch $url');
    }
  }

  sortNewsSourcesArray() {
    newsSourcesArray.sort((a, b) {
      // both - sort alphabetically
      if (favoriteNewsSources.contains(a['name']) &&
          favoriteNewsSources.contains(b['name']))
        return a['name'].compareTo(b['name']);
      // a and NOT b (a comes before b)
      else if (favoriteNewsSources.contains(a['name']) &&
          !favoriteNewsSources.contains(b['name']))
        return -1;
      // NOT a, but b (a comes after b)
      else if (!favoriteNewsSources.contains(a['name']) &&
          favoriteNewsSources.contains(b['name']))
        return 1;
      // none - sort alphabetically
      else
        return a['name'].compareTo(b['name']);
    });
  }

  Future refreshNewsStories() async {
    loadNewsStories();

    // Show refresh indicator for 3 seconds
    final Completer<Null> completer = new Completer<Null>();
    new Timer(const Duration(seconds: 2), () {
      completer.complete(null);
    });
    return completer.future;
  }

  saveThemeSelectionToDisk(bool useDarkTheme) async {
    prefs.setBool(USE_DARK_THEME, useDarkTheme);
  }

  getThemeSelectionFromDisk() async {
    bool shouldUseDarkTheme = prefs.getBool(USE_DARK_THEME);

    if (shouldUseDarkTheme != null)
      setState(() {
        useDarkTheme = shouldUseDarkTheme;
      });
  }

  saveFavoriteNewsSourcesToDisk() async {
    prefs.setStringList(FAVORITE_NEWS_SOURCES, favoriteNewsSources);
  }

  getFavoriteNewsSourcesFromDisk() async {
    if (prefs.getStringList(FAVORITE_NEWS_SOURCES) == null)
      favoriteNewsSources = new List();
    else
      favoriteNewsSources =
          new List<String>.from(prefs.getStringList(FAVORITE_NEWS_SOURCES));
  }

  Widget showImage(String imageUrl) {
    if (imageUrl != null && imageUrl != "")
      return new Image.network(imageUrl);
    else
      return new SizedBox(width: 0.0, height: 0.0);
  }

  initSharedPreferences() async {
    prefs = await SharedPreferences.getInstance();
  }
}
