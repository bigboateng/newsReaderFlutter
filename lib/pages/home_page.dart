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
  static const String USE_DARK_THEME = "USE_DARK_THEME";
  static const String CUSTOM_NEWS_SOURCES = "CUSTOM_NEWS_SOURCES";
  static const String US_TOP_NEWS = "US Top News";

  // Drop down menu selections
  static const String THEMES = "Themes";
  static const String SEARCH = "Search";
  static const String PROVIDER = "Provider";

  String currentTheme = "light_theme";

  bool shouldShowHelpText = false;
  bool userDidSearch = false;
  bool useDarkTheme = false;
  String appBarTitle = US_TOP_NEWS;
  String newsSourceId = "";
  List newsSourcesArray = [];
  List newsStoriesArray = [];
  List favoriteNewsSources = [];
  List customNewsSources = [];
  String _selectedNewsSource =
      US_TOP_NEWS; // used to highlight currently selected news source listTile
  AppLifecycleState _notification;

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
    setState(() {
      _notification = state;

      if (AppLifecycleState.resumed == state) refreshNewsStories();
    });
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

    http.Response reponse = await http.get(dataUrl);

    Map<String, dynamic> newsStories = JSON.decode(reponse.body);

    setState(() {
      newsStoriesArray = newsStories['articles'];
    });
  }

  loadTopUsHeadLines() async {
    userDidSearch = false;
    if (newsStoriesArray != null) newsStoriesArray.clear();

    String dataUrl =
        "https://newsapi.org/v2/top-headlines?country=us&apiKey=a30edf50cbbb48049945142f004c36c3";
    http.Response reponse = await http.get(dataUrl);

    Map<String, dynamic> newsStories = JSON.decode(reponse.body);

    setState(() {
      newsStoriesArray = newsStories['articles'];
    });
  }

  loadNewsSources() async {
    userDidSearch = false;

    String dataUrl =
        "https://newsapi.org/v2/sources?language=en&country=us&apiKey=a30edf50cbbb48049945142f004c36c3";

    http.Response response = await http.get(dataUrl);

    Map<String, dynamic> newsSources = JSON.decode(response.body);

    setState(() {
      newsSourcesArray = newsSources['sources'];
    });
  }

  loadNewsStories() async {
    userDidSearch = false;
    if (newsStoriesArray != null) newsStoriesArray.clear();

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
    userDidSearch = true;
    if (newsStoriesArray != null) newsStoriesArray.clear();

    String searchUrl = "https://newsapi.org/v2/everything?q=" +
        keyWord +
        "&language=en&sortBy=publishedAt&apiKey=a30edf50cbbb48049945142f004c36c3";

    http.Response response = await http.get(searchUrl);

    setState(() {
      Map<String, dynamic> newsStories = JSON.decode(response.body);
      newsStoriesArray = newsStories['articles'];
    });
  }

  /*
   * UI METHODS BEGIN
   */

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

  buildListOfNewsSources() {
    if (newsSourcesArray == null || newsSourcesArray.length == 0) {
      return new Drawer(
          child: new Center(child: new CircularProgressIndicator()));
    } else {
      return new Drawer(
          child: new Scrollbar(
              child: new ListView(
                  children: new List.generate(newsSourcesArray.length + 1,
                      (int index) {
        if (index == 0) {
          // generate home listTile
          return new Row(
            children: <Widget>[
              new IconButton(
                color: _selectedNewsSource == US_TOP_NEWS
                    ? _kGalleryDarkTheme.accentColor
                    : null,
                icon: new Icon(Icons.home,
                    color: _selectedNewsSource == US_TOP_NEWS
                        ? getAccentColor()
                        : null),
                onPressed: () => null,
                padding:
                    new EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              ),
              new Expanded(
                  child: new InkWell(
                child: new Text(US_TOP_NEWS,
                    style: new TextStyle(
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
          return new Row(
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
                padding:
                    new EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              ),
              new Expanded(
                child: new InkWell(
                  child: new Text(
                    newsSource,
                    style: new TextStyle(
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
              new Opacity(
                  opacity: customNewsSources.contains(newsSource) ? 1.0 : 0.0,
                  child: new IconButton(
                    icon: new Icon(Icons.remove_circle_outline,
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
    if (newsStoriesArray == null || newsStoriesArray.length == 0) {
      new Timer(new Duration(seconds: 6),
          () => setState(() => shouldShowHelpText = true));
      Opacity textOpacity = new Opacity(
          opacity: shouldShowHelpText ? 1.0 : 0.0,
          child: new Padding(
            padding: new EdgeInsets.symmetric(vertical: 20.0, horizontal: 30.0),
            child: new Text(
                "No data received from server.\nPlease check your internet connection.\n\nIf you are seeing this screen after adding a custom news source, then your custom news source is invalid.",
                style: new TextStyle(fontSize: 26.0),
                textAlign: TextAlign.center),
          ));

      return new Center(
          child: new Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          new CircularProgressIndicator(),
          textOpacity,
        ],
      ));
    } else {
      shouldShowHelpText = false;

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
                String newsSourceName =
                    newsStoriesArray[index]['source']['name'] == null
                        ? "No source"
                        : newsStoriesArray[index]['source']['name'];

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
                                  showImageIfAvailable(imageUrl),
                                  new Padding(
                                    padding: new EdgeInsets.fromLTRB(
                                        8.0, 8.0, 8.0, 8.0),
                                    child: new Text(title,
                                        textAlign: TextAlign.left,
                                        style: new TextStyle(
                                            fontSize: 26.0,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  showNewsSourceName(newsSourceName),
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

  buildAppBar() {
    return new AppBar(
      title: new Text(appBarTitle),
      actions: <Widget>[
        new PopupMenuButton<ListTile>(
          elevation: 16.0,
          itemBuilder: (BuildContext context) => <PopupMenuItem<ListTile>>[
                new PopupMenuItem<ListTile>(
                    child: new ListTile(
                  leading: const Icon(Icons.format_paint),
                  title: const Text(THEMES),
                  onTap: () {
                    Navigator.of(context).pop();
                    showThemeDialog();
                  },
                )),
                new PopupMenuItem<ListTile>(
                    child: new ListTile(
                  leading: const Icon(Icons.search),
                  title: const Text(SEARCH),
                  onTap: () {
                    Navigator.of(context).pop();
                    showSearchDialog();
                  },
                )),
                new PopupMenuItem<ListTile>(
                    child: new ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text(PROVIDER),
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
        child: new ThemeSelection(onThemeChosen: setTheme, currentTheme: this.currentTheme));
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
                      controller: _seachTextFieldController,
                      autofocus: true,
                      maxLength: 50,
                      maxLengthEnforced: true,
                      decoration:
                          new InputDecoration(icon: const Icon(Icons.search)),
                      onSubmitted: (asd) =>
                          beginNewsSearch(_seachTextFieldController.text),
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
                  beginNewsSearch(_seachTextFieldController.text);
                },
              ),
            ],
          )),
    );
  }

  Future<Null> showAddCustomNewsSourcesDialog() async {
    final customNewsSourceFormField = new GlobalKey<FormState>();
    TextEditingController _textFieldController = new TextEditingController();
    double screenWidth = MediaQuery.of(context).size.width;
    return showDialog<Null>(
      context: context,
      barrierDismissible: true,
      child: new Theme(
          data: useDarkTheme ? _kGalleryDarkTheme : _kGalleryLightTheme,
          child: new AlertDialog(
            title: new Text('Add News Provider'),
            content: new SingleChildScrollView(
              child: new ListBody(
                children: <Widget>[
                  new SizedBox(
                      width: screenWidth * 0.8,
                      height: 70.0,
                      child: new Form(
                          key: customNewsSourceFormField,
                          child: new TextFormField(
                            autofocus: true,
                            autocorrect: false,
                            decoration:
                                new InputDecoration(hintText: "mynews.com"),
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
              new FlatButton(
                child: new Text('CLOSE'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              new FlatButton(
                child: new Text('ADD'),
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
      return new Padding(
          padding: new EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
          child: new Opacity(
            opacity: 0.75,
            child: new Text(newsSource,
                style: new TextStyle(
                  fontSize: 14.0,
                  fontStyle: FontStyle.italic,
                )),
          ));
    } else {
      return new Padding(
        padding: new EdgeInsets.all(0.0),
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
    new Timer(const Duration(seconds: 2), () {
      completer.complete(null);
    });
    return completer.future;
  }

  void scrollToTop() {
    if (_scrollController.hasClients) _scrollController.jumpTo(0.0);
  }

  getThemeSelectionFromDisk() {
    String themeOnDisk = prefs.getString("theme");

    if (themeOnDisk != null)
      currentTheme = themeOnDisk;

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
      return new Image.network(imageUrl);
    else
      return new SizedBox(width: 0.0, height: 0.0);
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
  String currentTheme;

  ThemeSelection({this.onThemeChosen, this.currentTheme});

  @override
  _ThemeSelectionState createState() => new _ThemeSelectionState(currentTheme: this.currentTheme);
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
    return new Theme(
        data: currentTheme == "light_theme" ? _kGalleryLightTheme : _kGalleryDarkTheme,
        child: new AlertDialog(
          actions: <Widget>[
            new FlatButton(
              child: new Text('CLOSE'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            new FlatButton(
              child: new Text('SELECT'),
              onPressed: () {
                widget.onThemeChosen(themeGroupValue);
                Navigator.of(context).pop();
              },
            ),
          ],
          title: const Text("Choose Theme..."),
          content: new SingleChildScrollView(
              child: new ListBody(
            children: <Widget>[
              new RadioListTile(
                value: "light_theme",
                title: const Text("Light Theme"),
                groupValue: themeGroupValue,
                onChanged: (value) =>
                    setState(() => this.themeGroupValue = value),
              ),
              new RadioListTile(
                value: "dark_theme",
                title: const Text("Dark Theme"),
                groupValue: themeGroupValue,
                onChanged: (value) =>
                    setState(() => this.themeGroupValue = value),
              )
            ],
          )),
        ));
  }
}
