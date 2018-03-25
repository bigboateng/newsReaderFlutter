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
    accentColor: Colors.tealAccent);

final ThemeData _kGalleryLightTheme = new ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.blue,
    accentColor: Colors.blue);

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => new _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const String FAVORITE_NEWS_SOURCES = "FAVORITE_NEWS_SOURCES";
  static const String CUSTOM_NEWS_SOURCES = "CUSTOM_NEWS_SOURCES";
  static const String US_TOP_NEWS = "US Top News";

  // Drop down menu selections
  static const String THEMES = "Themes";
  static const String SEARCH = "Search";
  static const String PROVIDER = "Provider";

  String currentTheme = "light_theme";
  DateTime timeOfAppPaused;

  bool shouldShowHelpText = false;
  bool userDidSearch = false;
  bool useDarkTheme = false;
  String appBarTitle = US_TOP_NEWS;
  String newsSourceId = "";

  List newsSourcesArray = [];
  List newsStoriesArray = [];
  List favoriteNewsSources = [];
  List customNewsSources = [];

  bool noServerConnForNewsStories = false;
  bool noServerConnForNewsSources = false;
  bool isValidCustomNewsSource = true;

  String _selectedNewsSource =
      US_TOP_NEWS; // used to highlight currently selected news source listTile

  GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey();
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
    userDidSearch = false;
    if (newsStoriesArray != null) newsStoriesArray.clear();

    String dataUrl = "https://newsapi.org/v2/everything?domains=" +
        newsSourceId +
        "&apiKey=a30edf50cbbb48049945142f004c36c3";

    http.Response response = await http.get(dataUrl);

    setState(() {
      if (response.statusCode == 200) {
        Map<String, dynamic> newsStories = JSON.decode(response.body);

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
    userDidSearch = false;
    if (newsStoriesArray != null) newsStoriesArray.clear();

    String dataUrl =
        "https://newsapi.org/v2/top-headlines?country=us&apiKey=a30edf50cbbb48049945142f004c36c3";
    http.Response response = await http.get(dataUrl);

    if (response.statusCode == 200) {
      Map<String, dynamic> newsStories = JSON.decode(response.body);

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
    userDidSearch = false;

    String dataUrl =
        "https://newsapi.org/v2/sources?language=en&country=us&apiKey=a30edf50cbbb48049945142f004c36c3";

    http.Response response = await http.get(dataUrl);

    if (response.statusCode == 200) {
      Map<String, dynamic> newsSources = JSON.decode(response.body);

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
    userDidSearch = false;
    if (newsStoriesArray != null) newsStoriesArray.clear();

    String dataUrl = "https://newsapi.org/v2/top-headlines?sources=" +
        newsSourceId +
        "&apiKey=a30edf50cbbb48049945142f004c36c3";
    http.Response response = await http.get(dataUrl);

    if (response.statusCode == 200) {
      Map<String, dynamic> newsStories = JSON.decode(response.body);

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
    userDidSearch = true;
    if (newsStoriesArray != null) newsStoriesArray.clear();

    String searchUrl = "https://newsapi.org/v2/everything?q=" +
        keyWord +
        "&language=en&sortBy=publishedAt&apiKey=a30edf50cbbb48049945142f004c36c3";

    http.Response response = await http.get(searchUrl);

    if (response.statusCode == 200) {
      Map<String, dynamic> newsStories = JSON.decode(response.body);

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
        data: useDarkTheme ? _kGalleryDarkTheme : _kGalleryLightTheme,
        child: Scaffold(
            key: _scaffoldKey,
            appBar: buildAppBar(),
            drawer: buildListOfNewsSources(),
            body: buildListOfNewsStories()));
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
                      List.generate(newsSourcesArray.length + 1, (int index) {
        if (index == 0) {
          // generate home listTile
          return Row(
            children: <Widget>[
              new IconButton(
                color: _selectedNewsSource == US_TOP_NEWS
                    ? _kGalleryDarkTheme.accentColor
                    : null,
                icon: Icon(Icons.home,
                    color: _selectedNewsSource == US_TOP_NEWS
                        ? getAccentColor()
                        : null),
                onPressed: () => null,
                padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              ),
              Expanded(
                  child: InkWell(
                child: Text(US_TOP_NEWS,
                    style: TextStyle(
                        fontSize: 20.0,
                        color: _selectedNewsSource == US_TOP_NEWS
                            ? getAccentColor()
                            : null)),
                onTap: () {
                  appBarTitle = US_TOP_NEWS;
                  Navigator.pop(context);
                  _selectedNewsSource = US_TOP_NEWS;
                  loadTopUsHeadLines().then((asd) => scrollToTop());
                },
              ))
            ],
          );
        } else {
          index -= 1;
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
                child: InkWell(
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
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    newsSourceId = newsSourcesArray[index]['id'];
                    appBarTitle = newsSourcesArray[index]['name'];
                    _selectedNewsSource = newsSourcesArray[index]['name'];

                    if (customNewsSources.contains(newsSource))
                      loadNewsStoriesFromCustomSource()
                          .then((asd) => scrollToTop());
                    else
                      loadNewsStories().then((asd) => scrollToTop());
                  },
                ),
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
              padding:
                  EdgeInsets.symmetric(vertical: 20.0, horizontal: 30.0),
              child: Text(
                  "The news provider '$_selectedNewsSource' was not recognized.",
                  style: TextStyle(fontSize: 26.0),
                  textAlign: TextAlign.center)));
    } else if (noServerConnForNewsStories) {
      Timer(
          Duration(seconds: 6), () => setState(() => refreshNewsStories()));
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
        child: new RefreshIndicator(
            displacement: 80.0,
            onRefresh: () => refreshNewsStories(),
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
                                    padding: EdgeInsets.fromLTRB(
                                        8.0, 8.0, 8.0, 8.0),
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
                                                color: Colors.blue,
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

  buildAppBar() {
    return AppBar(
      title: Text(appBarTitle),
      actions: <Widget>[
        PopupMenuButton<ListTile>(
          elevation: 16.0,
          itemBuilder: (BuildContext context) => <PopupMenuItem<ListTile>>[
                PopupMenuItem<ListTile>(
                    child: ListTile(
                  leading: Icon(Icons.format_paint),
                  title: Text(THEMES),
                  onTap: () {
                    Navigator.of(context).pop();
                    showThemeDialog();
                  },
                )),
                PopupMenuItem<ListTile>(
                    child: ListTile(
                  leading: Icon(Icons.search),
                  title: Text(SEARCH),
                  onTap: () {
                    Navigator.of(context).pop();
                    showSearchDialog();
                  },
                )),
                PopupMenuItem<ListTile>(
                    child: ListTile(
                  leading: Icon(Icons.add),
                  title: Text(PROVIDER),
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
            onThemeChosen: setTheme, currentTheme: this.currentTheme));
  }

  void setTheme(String chosenTheme) {
    currentTheme = chosenTheme;

    switch (chosenTheme) {
      case 'light_theme':
        setState(() {
          useDarkTheme = false;
        });
        break;
      case 'dark_theme':
        setState(() {
          useDarkTheme = true;
        });
        break;
    }

    prefs.setString("theme", chosenTheme);
  }

  Future<Null> showSearchDialog() async {
    double screenWidth = MediaQuery.of(context).size.width;
    return showDialog<Null>(
      context: context,
      barrierDismissible: true,
      child: Theme(
          data: useDarkTheme ? _kGalleryDarkTheme : _kGalleryLightTheme,
          child: AlertDialog(
            title: Text('Search For News Articles...'),
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
                      decoration:
                          InputDecoration(icon: Icon(Icons.search)),
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

  Future<Null> showAddCustomNewsSourcesDialog() async {
    final customNewsSourceFormField = GlobalKey<FormState>();
    double screenWidth = MediaQuery.of(context).size.width;
    return showDialog<Null>(
      context: context,
      barrierDismissible: true,
      child: Theme(
          data: useDarkTheme ? _kGalleryDarkTheme : _kGalleryLightTheme,
          child: AlertDialog(
            title: Text('Add News Provider'),
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
                            decoration:
                                InputDecoration(hintText: "mynews.com"),
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
                  if (customNewsSourceFormField.currentState.validate())
                    customNewsSourceFormField.currentState.save();
                },
              ),
            ],
          )),
    );
  }

  /*
  * HELPER METHODS BEGIN
  */

  Widget showNewsSourceName(String newsSource) {
    if (userDidSearch || _selectedNewsSource == US_TOP_NEWS) {
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

  void addCustomNewsSource(String customNewsSource) {
    customNewsSources.add(customNewsSource);

    // save list to disk
    prefs.setStringList(CUSTOM_NEWS_SOURCES, customNewsSources);

    // Build map to add to newsSourcesArray
    Map<String, String> customNewsSourceMap = {
      'name': customNewsSource,
      'id': customNewsSource.toLowerCase()
    };

    Navigator.of(context).pop();
    newsSourcesArray.add(customNewsSourceMap);
    newsSourceId = customNewsSourceMap['id'];
    appBarTitle = customNewsSourceMap['name'];
    _selectedNewsSource = customNewsSourceMap['name'];

    sortNewsSourcesArray();

    setState(() {
      loadNewsStoriesFromCustomSource();
    });
  }

  beginNewsSearch(String keyword) {
    if (keyword.length > 0) {
      appBarTitle = "'" + keyword + "'";
      loadNewsStoriesFromSearch(keyword);
      Navigator.of(context).pop();
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

  Future refreshNewsStories() async {
    if (userDidSearch) // refresh a search result
      loadNewsStoriesFromSearch(_seachTextFieldController.text)
          .then((asd) => scrollToTop());
    else if (customNewsSources.contains(
        _selectedNewsSource)) // refresh news from a custom news source
      loadNewsStoriesFromCustomSource().then((asd) => scrollToTop());
    else if (_selectedNewsSource == US_TOP_NEWS) // refresh the homepage news
      loadTopUsHeadLines().then((asd) => scrollToTop());
    else // refresh news from the selected standard source
      loadNewsStories().then((asd) => scrollToTop());

    // Show refresh indicator for 3 seconds
    final Completer<Null> completer = new Completer<Null>();
    new Timer(Duration(seconds: 2), () {
      completer.complete(null);
    });
    return completer.future;
  }

  void scrollToTop() {
    if (_scrollController.hasClients) _scrollController.jumpTo(0.0);
  }

  getThemeSelectionFromDisk() {
    String themeOnDisk = prefs.getString("theme");

    if (themeOnDisk != null) currentTheme = themeOnDisk;

    setState(() {
      useDarkTheme = themeOnDisk == "dark_theme";
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
    if (useDarkTheme)
      return _kGalleryDarkTheme.accentColor;
    else
      return _kGalleryLightTheme.accentColor;
  }
}

/*
  Classes that holds the state of theme selection dialog
 */

typedef void ThemeSelectionCallback(String chosenTheme);

class ThemeSelection extends StatefulWidget {
  final ThemeSelectionCallback onThemeChosen;
  final String currentTheme;

  ThemeSelection({this.onThemeChosen, this.currentTheme});

  @override
  _ThemeSelectionState createState() =>
      new _ThemeSelectionState(currentTheme: this.currentTheme);
}

class _ThemeSelectionState extends State<ThemeSelection> {
  String themeGroupValue = "light_theme";
  String currentTheme;

  _ThemeSelectionState({this.currentTheme});

  @override
  void initState() {
    super.initState();
    themeGroupValue = currentTheme;
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
        data: currentTheme == "light_theme"
            ? _kGalleryLightTheme
            : _kGalleryDarkTheme,
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
          title: Text("Choose Theme..."),
          content: SingleChildScrollView(
              child: ListBody(
            children: <Widget>[
              RadioListTile(
                value: "light_theme",
                title: Text("Light Theme"),
                groupValue: themeGroupValue,
                onChanged: (value) =>
                    setState(() => this.themeGroupValue = value),
              ),
              RadioListTile(
                value: "dark_theme",
                title: Text("Dark Theme"),
                groupValue: themeGroupValue,
                onChanged: (value) =>
                    setState(() => this.themeGroupValue = value),
              )
            ],
          )),
        ));
  }
}
