import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share/share.dart' as sharing;

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => new _HomePageState();
}

enum LastUserAction { search, categories, customNews, news, usTopNews }

enum MyThemes {
  defaultDark,
  defaultLight,
  darkTeal,
  darkCyan,
  darkPurple,
  darkGreen,
  darkYellow,
  darkPink
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const String FAVORITE_NEWS_SOURCES = "FAVORITE_NEWS_SOURCES";
  static const String CUSTOM_NEWS_SOURCES = "CUSTOM_NEWS_SOURCES";
  static const String US_TOP_NEWS = "US Top News";

  // Drop down menu selections
  static const String THEMES = "Themes";
  static const String SEARCH = "Search";
  static const String PROVIDER = "Provider";

  String appBarTitle = US_TOP_NEWS;
  String newsSourceId = "";
  static MyThemes currentSelectedTheme = MyThemes.defaultLight;

  DateTime timeOfAppPaused;

  bool shouldShowHelpText = false;
  bool noServerConnForNewsStories = false;
  bool noServerConnForNewsSources = false;
  bool isValidCustomNewsSource = true;

  List newsSourcesArray = [];
  List newsStoriesArray = [];
  List<String> favoriteNewsSources = new List<String>();
  List<String> customNewsSources = new List<String>();

  LastUserAction lastUserAction = LastUserAction.usTopNews;

  // used to highlight currently selected news source listTile
  String _selectedNewsSource = US_TOP_NEWS;

  GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      new GlobalKey<RefreshIndicatorState>();
  ScrollController _scrollController = new ScrollController();
  TextEditingController _seachTextFieldController = new TextEditingController();
  SharedPreferences prefs;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
        .addObserver(this); // used for detecting app lifecycle

    loadTopUsHeadLines()
        .then((asd) => initSharedPreferences())
        .then((asd) => getFavoriteNewsSourcesFromDisk())
        .then((asd) => loadNewsSources())
        .then((asd) => getCustomNewsSourcesFromDisk())
        .then((asd) => sortNewsSourcesArray())
        .then((asd) => getThemeSelectionFromDisk());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (AppLifecycleState.resumed == state) {
      // only refresh news stories if 10mins have passed since app was paused
      DateTime now = new DateTime.now();
      Duration timeSinceAppWasPaused = now.difference(timeOfAppPaused);

      if (timeSinceAppWasPaused.inMinutes >= 10) refreshNewsStories();
    } else if (AppLifecycleState.paused == state)
      // save current time to memory
      timeOfAppPaused = new DateTime.now();
  }

  /*
   * HTTP METHODS BEGIN
   */

  loadNewsStoriesFromCustomSource() async {
    if (newsStoriesArray != null) newsStoriesArray.clear();

    String dataUrl = "https://newsapi.org/v2/everything?domains=" +
        newsSourceId +
        "&apiKey=a30edf50cbbb48049945142f004c36c3";

    http.Response response = await http.get(dataUrl);

    setState(() {
      if (response.statusCode == 200) {
        Map<String, dynamic> newsStories = json.decode(response.body);

        if (newsStories['totalResults'] == 0)
          isValidCustomNewsSource = false;
        else {
          isValidCustomNewsSource = true;
          newsStoriesArray = newsStories['articles'];
        }
      } else {
        noServerConnForNewsStories = true;
      }
    });
  }

  loadTopUsHeadLines() async {
    isValidCustomNewsSource = true;

    if (newsStoriesArray != null) newsStoriesArray.clear();

    String dataUrl =
        "https://newsapi.org/v2/top-headlines?country=us&apiKey=a30edf50cbbb48049945142f004c36c3";
    http.Response response = await http.get(dataUrl);

    if (response.statusCode == 200) {
      Map<String, dynamic> newsStories = json.decode(response.body);

      setState(() {
        noServerConnForNewsStories = false;
        newsStoriesArray = newsStories['articles'];
      });
    } else {
      setState(() {
        noServerConnForNewsStories = true;
      });
    }
  }

  loadNewsSources() async {
    isValidCustomNewsSource = true;

    String dataUrl =
        "https://newsapi.org/v2/sources?language=en&country=us&apiKey=a30edf50cbbb48049945142f004c36c3";

    http.Response response = await http.get(dataUrl);

    if (response.statusCode == 200) {
      Map<String, dynamic> newsSources = json.decode(response.body);

      setState(() {
        newsSourcesArray = newsSources['sources'];
        noServerConnForNewsSources = false;
      });
    } else {
      setState(() {
        noServerConnForNewsSources = true;
      });
    }
  }

  loadNewsStories() async {
    isValidCustomNewsSource = true;

    if (newsStoriesArray != null) newsStoriesArray.clear();

    String dataUrl = "https://newsapi.org/v2/top-headlines?sources=" +
        newsSourceId +
        "&apiKey=a30edf50cbbb48049945142f004c36c3";
    http.Response response = await http.get(dataUrl);

    if (response.statusCode == 200) {
      Map<String, dynamic> newsStories = json.decode(response.body);

      setState(() {
        noServerConnForNewsStories = false;
        newsStoriesArray = newsStories['articles'];
      });
    } else {
      setState(() {
        noServerConnForNewsStories = true;
      });
    }
  }

  loadNewsStoriesFromSearch(String keyWord) async {
    isValidCustomNewsSource = true;

    if (newsStoriesArray != null) newsStoriesArray.clear();

    String searchUrl = "https://newsapi.org/v2/everything?q=" +
        keyWord +
        "&language=en&sortBy=publishedAt&apiKey=a30edf50cbbb48049945142f004c36c3";

    http.Response response = await http.get(searchUrl);

    if (response.statusCode == 200) {
      Map<String, dynamic> newsStories = json.decode(response.body);

      setState(() {
        noServerConnForNewsStories = false;
        newsStoriesArray = newsStories['articles'];
      });
    } else {
      setState(() {
        noServerConnForNewsStories = true;
      });
    }
  }

  loadNewsStoriesFromCategory() async {
    isValidCustomNewsSource = true;

    if (newsStoriesArray != null) newsStoriesArray.clear();

    String dataUrl =
        "https://newsapi.org/v2/top-headlines?country=us&category=" +
            _selectedNewsSource +
            "&apiKey=a30edf50cbbb48049945142f004c36c3";

    http.Response response = await http.get(dataUrl);

    if (response.statusCode == 200) {
      Map<String, dynamic> newsStories = json.decode(response.body);

      setState(() {
        noServerConnForNewsStories = false;
        newsStoriesArray = newsStories['articles'];
      });
    } else {
      setState(() {
        noServerConnForNewsStories = true;
      });
    }
  }

  /*
   * UI METHODS BEGIN
   */

  @override
  Widget build(BuildContext context) {
    return Theme(
        data: getCurrentTheme(),
        child: Scaffold(
            key: _scaffoldKey,
            appBar: buildAppBar(),
            drawer: buildListOfNewsSources(),
            body: buildListOfNewsStories()));
  }

  buildNewsCategories() {
    double iconSize = 60.0;
    double textSize = 20.0;
    Color iconColor = Colors.black;
    Color textColor = Colors.black;

    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      childAspectRatio: 1.0,
      children: <Widget>[
        InkWell(
          onTap: () {
            Navigator.pop(context);
            newsSourceId = "business";
            _selectedNewsSource = "business";
            appBarTitle = "Business";
            lastUserAction = LastUserAction.categories;
            _refreshIndicatorKey.currentState.show();
          },
          child: Container(
              decoration: BoxDecoration(color: Color(0xFF69F0AE)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Container(),
                  Center(
                      child: Icon(Icons.attach_money,
                          size: iconSize, color: iconColor)),
                  Text(
                    "BUSINESS",
                    style: TextStyle(fontSize: textSize, color: textColor),
                  )
                ],
              )),
        ),
        InkWell(
          onTap: () {
            Navigator.pop(context);
            newsSourceId = "technology";
            _selectedNewsSource = "technology";
            appBarTitle = "Tech";
            lastUserAction = LastUserAction.categories;
            _refreshIndicatorKey.currentState.show();
          },
          child: Container(
              decoration: BoxDecoration(color: Color(0xFFFFD740)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Container(),
                  Icon(Icons.smartphone, size: iconSize, color: iconColor),
                  Text(
                    "TECH",
                    style: TextStyle(fontSize: textSize, color: textColor),
                  )
                ],
              )),
        ),
        InkWell(
          onTap: () {
            Navigator.pop(context);
            newsSourceId = "science";
            _selectedNewsSource = "science";
            appBarTitle = "Science";
            lastUserAction = LastUserAction.categories;
            _refreshIndicatorKey.currentState.show();
          },
          child: Container(
              decoration: BoxDecoration(color: Color(0xFFE040FB)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Container(),
                  Icon(Icons.bubble_chart, size: iconSize, color: iconColor),
                  Text(
                    "SCIENCE",
                    style: TextStyle(fontSize: textSize, color: textColor),
                  )
                ],
              )),
        ),
        InkWell(
          onTap: () {
            Navigator.pop(context);
            newsSourceId = "sports";
            _selectedNewsSource = "sports";
            appBarTitle = "Sports";
            lastUserAction = LastUserAction.categories;
            _refreshIndicatorKey.currentState.show();
          },
          child: Container(
              decoration: BoxDecoration(color: Color(0xFF40C4FF)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Container(),
                  Icon(Icons.golf_course, size: iconSize, color: iconColor),
                  Text(
                    "SPORTS",
                    style: TextStyle(fontSize: textSize, color: textColor),
                  )
                ],
              )),
        ),
        InkWell(
          onTap: () {
            Navigator.pop(context);
            newsSourceId = "health";
            _selectedNewsSource = "health";
            appBarTitle = "Health";
            lastUserAction = LastUserAction.categories;
            _refreshIndicatorKey.currentState.show();
          },
          child: Container(
              decoration: BoxDecoration(color: Color(0xFF536DFE)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Container(),
                  Icon(Icons.favorite_border, size: iconSize, color: iconColor),
                  Text(
                    "HEALTH",
                    style: TextStyle(fontSize: textSize, color: textColor),
                  )
                ],
              )),
        ),
        InkWell(
          onTap: () {
            Navigator.pop(context);
            newsSourceId = "entertainment";
            _selectedNewsSource = "entertainment";
            appBarTitle = "Showbiz";
            lastUserAction = LastUserAction.categories;
            _refreshIndicatorKey.currentState.show();
          },
          child: Container(
              decoration: BoxDecoration(color: Color(0XFFFF5252)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Container(),
                  Icon(Icons.local_movies, size: iconSize, color: iconColor),
                  Text(
                    "SHOWBIZ",
                    style: TextStyle(fontSize: textSize, color: textColor),
                  )
                ],
              )),
        ),
      ],
    );
  }

  buildListOfNewsSources() {
    if (noServerConnForNewsSources) {
      Timer(Duration(seconds: 5), () => loadNewsSources());
      return Drawer(
          child: Center(
              child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          CircularProgressIndicator(),
          Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("Retrying connection...",
                  style: TextStyle(fontSize: 14.0),
                  textAlign: TextAlign.center)),
        ],
      )));
    } else {
      return Drawer(
          child: Scrollbar(
              child: ListView(
                  children:
                      List.generate(newsSourcesArray.length + 2, (int index) {
        if (index == 0) {
          // generate news categories
          return buildNewsCategories();
        } else if (index == 1) {
          // generate home listTile
          return Row(
            children: <Widget>[
              new IconButton(
                color: _selectedNewsSource == US_TOP_NEWS
                    ? defaultDarkTheme.accentColor
                    : null,
                icon: Icon(Icons.home,
                    color: _selectedNewsSource == US_TOP_NEWS
                        ? getAccentColor()
                        : null),
                onPressed: () => null,
                padding: EdgeInsets.fromLTRB(16.0, 24.0, 8.0, 12.0),
              ),
              Expanded(
                  child: InkWell(
                child: Padding(
                    padding: EdgeInsets.fromLTRB(8.0, 24.0, 8.0, 12.0),
                    child: Text(US_TOP_NEWS,
                        style: TextStyle(
                            fontSize: 20.0,
                            color: _selectedNewsSource == US_TOP_NEWS
                                ? getAccentColor()
                                : null))),
                onTap: () {
                  appBarTitle = US_TOP_NEWS;
                  lastUserAction = LastUserAction.usTopNews;
                  Navigator.pop(context);
                  _selectedNewsSource = US_TOP_NEWS;
                  _refreshIndicatorKey.currentState.show();
                },
              ))
            ],
          );
        } else {
          index -= 2;
          String newsSource = newsSourcesArray[index]['name'];
          return Row(
            children: <Widget>[
              new IconButton(
                icon: favoriteNewsSources.contains(newsSource)
                    ? new Icon(Icons.star,
                        color: _selectedNewsSource == newsSource
                            ? getAccentColor()
                            : null)
                    : new Icon(Icons.star_border,
                        color: _selectedNewsSource == newsSource
                            ? getAccentColor()
                            : null),
                onPressed: () {
                  if (favoriteNewsSources.contains(newsSource))
                    favoriteNewsSources.remove(newsSource);
                  else
                    favoriteNewsSources.add(newsSource);

                  saveFavoriteNewsSourcesToDisk();

                  setState(() {
                    sortNewsSourcesArray();
                  });
                },
                padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              ),
              Expanded(
                child: SizedBox(
                    height: 50.0,
                    child: InkWell(
                      child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            newsSource,
                            style: TextStyle(
                                fontSize: 20.0,
                                color: _selectedNewsSource ==
                                        newsSourcesArray[index]['name']
                                    ? getAccentColor()
                                    : null),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          )),
                      onTap: () {
                        Navigator.pop(context);
                        newsSourceId = newsSourcesArray[index]['id'];
                        appBarTitle = newsSourcesArray[index]['name'];
                        _selectedNewsSource = newsSourcesArray[index]['name'];

                        if (customNewsSources.contains(newsSource)) {
                          lastUserAction = LastUserAction.customNews;
                          _refreshIndicatorKey.currentState.show();
                        } else {
                          lastUserAction = LastUserAction.news;
                          _refreshIndicatorKey.currentState.show();
                        }
                      },
                    )),
              ),
              Opacity(
                  opacity: customNewsSources.contains(newsSource) ? 1.0 : 0.0,
                  child: IconButton(
                    icon: Icon(Icons.remove_circle_outline,
                        color: _selectedNewsSource == newsSource
                            ? getAccentColor()
                            : null),
                    onPressed: () {
                      if (customNewsSources.contains(newsSource)) {
                        customNewsSources.remove(newsSource);
                        newsSourcesArray.removeAt(index);
                        prefs.setStringList(
                            CUSTOM_NEWS_SOURCES, customNewsSources);
                      }
                      setState(() {
                        sortNewsSourcesArray();
                      });
                    },
                  )),
            ],
          );
        }
      }))));
    }
  }

  buildListOfNewsStories() {
    if (!isValidCustomNewsSource) {
      return Center(
          child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 30.0),
              child: Text(
                  "The news provider '$_selectedNewsSource' was not recognized.",
                  style: TextStyle(fontSize: 26.0),
                  textAlign: TextAlign.center)));
    } else if (noServerConnForNewsStories) {
      Timer(Duration(seconds: 6), () => refreshNewsStories());
      return Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          CircularProgressIndicator(),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 30.0),
            child: Text(
                "No data received from server.\nPlease check your internet connection. Reconnecting...",
                style: TextStyle(fontSize: 26.0),
                textAlign: TextAlign.center),
          )
        ],
      ));
    } else {
      return Scrollbar(
        child: RefreshIndicator(
            onRefresh: refreshNewsStories,
            key: _refreshIndicatorKey,
            child: ListView(
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
                String newsSourceName =
                    newsStoriesArray[index]['source']['name'] == null
                        ? "No source"
                        : newsStoriesArray[index]['source']['name'];

                String formattedDate = formatDateForUi(dateTime);

                return Padding(
                    padding: EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                    child: InkWell(
                        onTap: () => _launchURL(url),
                        child: Card(
                            elevation: 5.0,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  showImageIfAvailable(imageUrl),
                                  Padding(
                                    padding:
                                        EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 8.0),
                                    child: Text(title,
                                        textAlign: TextAlign.left,
                                        style: TextStyle(
                                            fontSize: 26.0,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  showNewsSourceName(newsSourceName),
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                        16.0, 8.0, 16.0, 8.0),
                                    child: Text(newsText,
                                        style: TextStyle(fontSize: 16.0)),
                                  ),
                                  Padding(
                                      padding: EdgeInsets.fromLTRB(
                                          16.0, 16.0, 16.0, 8.0),
                                      child: Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: Text(formattedDate,
                                                style: TextStyle(
                                                    fontStyle:
                                                        FontStyle.italic)),
                                          ),
                                          IconButton(
                                              icon: Icon(
                                                Icons.share,
                                                color: getAccentColor(),
                                              ),
                                              padding: EdgeInsets.fromLTRB(
                                                  0.0, 0.0, 16.0, 0.0),
                                              iconSize: 32.0,
                                              onPressed: () => sharing.share(
                                                  '"' +
                                                      title +
                                                      '"' +
                                                      " " +
                                                      url)),
                                          Text("READ MORE",
                                              style: TextStyle(
                                                  fontSize: 16.0,
                                                  color: getAccentColor(),
                                                  fontWeight: FontWeight.bold))
                                        ],
                                      ))
                                ]))));
              }),
            )),
      );
    }
  }

  buildAppBar() {
    Color accentColor = currentSelectedTheme == MyThemes.defaultLight
        ? Colors.white
        : getAccentColor();
    return AppBar(
      leading: IconButton(
          icon: Icon(Icons.menu, color: accentColor),
          onPressed: () => _scaffoldKey.currentState.openDrawer()),
      title: Text(appBarTitle, style: TextStyle(color: accentColor)),
      actions: <Widget>[
        PopupMenuButton<ListTile>(
          icon: Icon(Icons.more_vert, color: accentColor),
          elevation: 16.0,
          itemBuilder: (BuildContext context) => <PopupMenuItem<ListTile>>[
                PopupMenuItem<ListTile>(
                    child: ListTile(
                  leading: Icon(Icons.palette, color: getAccentColor()),
                  title:
                      Text(THEMES, style: TextStyle(color: getAccentColor())),
                  onTap: () {
                    Navigator.of(context).pop();
                    showThemeDialog();
                  },
                )),
                PopupMenuItem<ListTile>(
                    child: ListTile(
                  leading: Icon(Icons.search, color: getAccentColor()),
                  title:
                      Text(SEARCH, style: TextStyle(color: getAccentColor())),
                  onTap: () {
                    Navigator.of(context).pop();
                    showSearchDialog();
                  },
                )),
                PopupMenuItem<ListTile>(
                    child: ListTile(
                  leading: Icon(Icons.add, color: getAccentColor()),
                  title:
                      Text(PROVIDER, style: TextStyle(color: getAccentColor())),
                  onTap: () {
                    Navigator.of(context).pop();
                    showAddCustomNewsSourcesDialog();
                  },
                )),
              ],
        ),
      ],
    );
  }

  Future<Null> showThemeDialog() async {
    return showDialog<Null>(
        context: context,
        barrierDismissible: true,
        child: ThemeSelection(
            onThemeChosen: setTheme, currentTheme: currentSelectedTheme));
  }

  void setTheme(MyThemes chosenTheme) {
    setState(() => currentSelectedTheme = chosenTheme);

    prefs.setInt("theme", chosenTheme.index);
  }

  Future<Null> showSearchDialog() async {
    double screenWidth = MediaQuery.of(context).size.width;
    return showDialog<Null>(
      context: context,
      barrierDismissible: true,
      child: Theme(
          data: getCurrentTheme(),
          child: AlertDialog(
            title: Text('Search For News Articles...',
                style: TextStyle(color: getAccentColor())),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  SizedBox(
                    width: screenWidth * 0.8,
                    height: 50.0,
                    child: TextField(
                      controller: _seachTextFieldController,
                      autofocus: true,
                      maxLength: 50,
                      maxLengthEnforced: true,
                      decoration: InputDecoration(icon: Icon(Icons.search)),
                      onSubmitted: (asd) =>
                          beginNewsSearch(_seachTextFieldController.text),
                    ),
                  )
                ],
              ),
            ),
            actions: <Widget>[
              FlatButton(
                child: Text('CLOSE'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              FlatButton(
                child: Text('SEARCH'),
                onPressed: () {
                  beginNewsSearch(_seachTextFieldController.text);
                },
              ),
            ],
          )),
    );
  }

  beginNewsSearch(String keyword) {
    if (keyword.length > 0) {
      appBarTitle = "'" + keyword + "'";
      _selectedNewsSource = appBarTitle;
      newsSourceId = appBarTitle;
      lastUserAction = LastUserAction.search;
      _refreshIndicatorKey.currentState.show();
      Navigator.of(context).pop();
    }
  }

  Future<Null> showAddCustomNewsSourcesDialog() async {
    final customNewsSourceFormField = GlobalKey<FormState>();
    double screenWidth = MediaQuery.of(context).size.width;
    return showDialog<Null>(
      context: context,
      barrierDismissible: true,
      child: Theme(
          data: getCurrentTheme(),
          child: AlertDialog(
            title: Text('Add News Provider',
                style: TextStyle(color: getAccentColor())),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  SizedBox(
                      width: screenWidth * 0.8,
                      height: 70.0,
                      child: Form(
                          key: customNewsSourceFormField,
                          child: TextFormField(
                            autofocus: true,
                            autocorrect: false,
                            decoration: InputDecoration(hintText: "mynews.com"),
                            onSaved: (val) => addCustomNewsSource(val),
                            onFieldSubmitted: ((val) {
                              if (val.isEmpty)
                                return "You must enter a url like mynews.com";
                              else if (customNewsSources.contains(val))
                                return "Custom news source already exists";
                              else
                                return null;
                            }),
                            validator: ((val) {
                              if (val.isEmpty)
                                return "You must enter a url like mynews.com";
                              else if (customNewsSources.contains(val))
                                return "Custom news source already exists";
                              else
                                return null;
                            }),
                          )))
                ],
              ),
            ),
            actions: <Widget>[
              FlatButton(
                child: Text('CLOSE'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              FlatButton(
                child: Text('ADD'),
                onPressed: () {
                  if (customNewsSourceFormField.currentState.validate()) {
                    customNewsSourceFormField.currentState.save();
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          )),
    );
  }

  /*
  * HELPER METHODS BEGIN
  */

  static ThemeData getCurrentTheme() {
    switch (currentSelectedTheme) {
      case MyThemes.defaultLight:
        return defaultLightTheme;
        break;
      case MyThemes.defaultDark:
        return defaultDarkTheme;
        break;
      case MyThemes.darkYellow:
        return darkYellow;
        break;
      case MyThemes.darkCyan:
        return darkCyan;
        break;
      case MyThemes.darkGreen:
        return darkGreen;
        break;
      case MyThemes.darkPurple:
        return darkPurple;
        break;
      case MyThemes.darkPink:
        return darkPink;
        break;
      case MyThemes.darkTeal:
        return darkTeal;
        break;
    }

    return defaultLightTheme;
  }

  void addCustomNewsSource(String customNewsSource) {
    customNewsSources.add(customNewsSource);

    // save list to disk
    prefs.setStringList(CUSTOM_NEWS_SOURCES, customNewsSources);

    // Build map to add to newsSourcesArray
    Map<String, String> customNewsSourceMap = {
      'name': customNewsSource,
      'id': customNewsSource.toLowerCase()
    };

    newsSourcesArray.add(customNewsSourceMap);
    newsSourceId = customNewsSourceMap['id'];
    appBarTitle = customNewsSourceMap['name'];
    _selectedNewsSource = customNewsSourceMap['name'];

    sortNewsSourcesArray();

    lastUserAction = LastUserAction.customNews;
    _refreshIndicatorKey.currentState.show();
  }

  Widget showNewsSourceName(String newsSource) {
    if (lastUserAction == LastUserAction.search ||
        lastUserAction == LastUserAction.usTopNews ||
        lastUserAction == LastUserAction.categories) {
      return Padding(
          padding: EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
          child: Opacity(
            opacity: 0.75,
            child: Text(newsSource,
                style: TextStyle(
                  fontSize: 14.0,
                  fontStyle: FontStyle.italic,
                )),
          ));
    } else {
      return Padding(
        padding: EdgeInsets.all(0.0),
      );
    }
  }

  String formatDateForUi(String dateTime) {
    String formattedDate = "";

    if (dateTime != "") {
      String newDateTime = dateTime.substring(0, 19) + "Z";
      DateTime dtObj = DateTime.parse(newDateTime);
      DateTime localDtObj = dtObj.toLocal();
      DateFormat formatter = new DateFormat("MMMM d. yyyy h:mm a");
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

  Future<Null> refreshNewsStories() {
    Completer<Null> completer = new Completer<Null>();

    switch (lastUserAction) {
      case LastUserAction.categories:
        loadNewsStoriesFromCategory()
            .then((asd) => completer.complete())
            .then((asd) => scrollToTop());
        break;
      case LastUserAction.usTopNews:
        loadTopUsHeadLines()
            .then((asd) => completer.complete())
            .then((asd) => scrollToTop());
        break;
      case LastUserAction.search:
        loadNewsStoriesFromSearch(_seachTextFieldController.text)
            .then((asd) => completer.complete())
            .then((asd) => scrollToTop());
        break;
      case LastUserAction.customNews:
        loadNewsStoriesFromCustomSource()
            .then((asd) => completer.complete())
            .then((asd) => scrollToTop());
        break;
      case LastUserAction.news:
        loadNewsStories()
            .then((asd) => completer.complete())
            .then((asd) => scrollToTop());
        break;
    }

    return completer.future;
  }

  void scrollToTop() {
    if (_scrollController.hasClients) _scrollController.jumpTo(0.0);
  }

  getThemeSelectionFromDisk() {
    setState(() {
      currentSelectedTheme = MyThemes.values[prefs.getInt("theme") ?? 0];
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

  getCustomNewsSourcesFromDisk() async {
    if (prefs.getStringList(CUSTOM_NEWS_SOURCES) == null)
      customNewsSources = new List();
    else
      customNewsSources =
          new List<String>.from(prefs.getStringList(CUSTOM_NEWS_SOURCES));

    for (String customNewsSource in customNewsSources) {
      Map<String, String> customNewsSourceMap = {
        'name': customNewsSource,
        'id': customNewsSource.toLowerCase()
      };
      newsSourcesArray.add(customNewsSourceMap);
    }
  }

  Widget showImageIfAvailable(String imageUrl) {
    if (imageUrl != null && imageUrl != "")
      return Image.network(imageUrl);
    else
      return SizedBox(width: 0.0, height: 0.0);
  }

  initSharedPreferences() async {
    prefs = await SharedPreferences.getInstance();
  }

  Color getAccentColor() {
    ThemeData theme = getCurrentTheme();
    return theme.accentColor;
  }
}

/*
  Classes that holds the state of theme selection dialog
 */

final ThemeData defaultLightTheme = new ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.blue,
    accentColor: Colors.blueAccent);

final ThemeData defaultDarkTheme = new ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.lightBlue,
    accentColor: Colors.lightBlueAccent);

final ThemeData darkTeal = new ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.teal,
    accentColor: Colors.tealAccent);

final ThemeData darkCyan = new ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.cyan,
    accentColor: Colors.cyanAccent);

final ThemeData darkPurple = new ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.purple,
    accentColor: Colors.purpleAccent);

final ThemeData darkGreen = new ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.green,
    accentColor: Colors.greenAccent);

final ThemeData darkYellow = new ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.yellow,
    accentColor: Colors.yellowAccent);

final ThemeData darkPink = new ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.pink,
    accentColor: Colors.pinkAccent);

typedef void ThemeSelectionCallback(MyThemes chosenTheme);

class ThemeSelection extends StatefulWidget {
  final ThemeSelectionCallback onThemeChosen;
  final MyThemes currentTheme;

  ThemeSelection({this.onThemeChosen, this.currentTheme});

  @override
  _ThemeSelectionState createState() =>
      new _ThemeSelectionState(currentTheme: this.currentTheme);
}

class _ThemeSelectionState extends State<ThemeSelection> {
  MyThemes currentTheme;
  MyThemes themeGroupValue = MyThemes.defaultLight;

  _ThemeSelectionState({this.currentTheme});

  @override
  void initState() {
    super.initState();
    themeGroupValue = currentTheme;
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
        data: _HomePageState.getCurrentTheme() == defaultLightTheme
            ? darkCyan
            : _HomePageState.getCurrentTheme(),
        child: AlertDialog(
          actions: <Widget>[
            FlatButton(
              child: Text('CLOSE'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            FlatButton(
              child: Text('SELECT'),
              onPressed: () {
                widget.onThemeChosen(themeGroupValue);
                Navigator.of(context).pop();
              },
            ),
          ],
          //title: Text("Choose Theme...", style: TextStyle(color: _HomePageState.getCurrentTheme() == defaultLightTheme ? darkCyan.accentColor : _HomePageState.getCurrentTheme().accentColor)),
          title: Text("Choose Theme...",
              style: TextStyle(
                  color: currentTheme == MyThemes.defaultLight
                      ? darkCyan.accentColor
                      : _HomePageState.getCurrentTheme().accentColor)),
          content: SingleChildScrollView(
              child: ListBody(
            children: <Widget>[
              RadioListTile(
                value: MyThemes.defaultLight,
                title: Text("Default Light",
                    style: TextStyle(color: Colors.white)),
                groupValue: themeGroupValue,
                onChanged: (value) =>
                    setState(() => this.themeGroupValue = value),
              ),
              RadioListTile(
                value: MyThemes.defaultDark,
                title: Text("Default Dark",
                    style: TextStyle(color: defaultDarkTheme.accentColor)),
                groupValue: themeGroupValue,
                onChanged: (value) =>
                    setState(() => this.themeGroupValue = value),
              ),
              RadioListTile(
                value: MyThemes.darkTeal,
                title: Text("Dark  / Teal",
                    style: TextStyle(color: darkTeal.accentColor)),
                groupValue: themeGroupValue,
                onChanged: (value) =>
                    setState(() => this.themeGroupValue = value),
              ),
              RadioListTile(
                value: MyThemes.darkCyan,
                title: Text("Dark  / Cyan",
                    style: TextStyle(color: darkCyan.accentColor)),
                groupValue: themeGroupValue,
                onChanged: (value) =>
                    setState(() => this.themeGroupValue = value),
              ),
              RadioListTile(
                value: MyThemes.darkPurple,
                title: Text("Dark  / Purple",
                    style: TextStyle(color: darkPurple.accentColor)),
                groupValue: themeGroupValue,
                onChanged: (value) =>
                    setState(() => this.themeGroupValue = value),
              ),
              RadioListTile(
                value: MyThemes.darkGreen,
                title: Text("Dark  / Green",
                    style: TextStyle(color: darkGreen.accentColor)),
                groupValue: themeGroupValue,
                onChanged: (value) =>
                    setState(() => this.themeGroupValue = value),
              ),
              RadioListTile(
                value: MyThemes.darkYellow,
                title: Text("Dark  / Yellow",
                    style: TextStyle(color: darkYellow.accentColor)),
                groupValue: themeGroupValue,
                onChanged: (value) =>
                    setState(() => this.themeGroupValue = value),
              ),
              RadioListTile(
                value: MyThemes.darkPink,
                title: Text("Dark  / Pink",
                    style: TextStyle(color: darkPink.accentColor)),
                groupValue: themeGroupValue,
                onChanged: (value) =>
                    setState(() => this.themeGroupValue = value),
              ),
            ],
          )),
        ));
  }
}
