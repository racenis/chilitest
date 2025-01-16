// ignore_for_file: avoid_print

// TODO LIST
// - squish the textbox a little bit
// - when nothing is found? then say that
// - restore search text to the search box

import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;

import 'dart:convert';

// you're not supposed to put API keys in source code, but whatever 🚀🚀🚀
const String GIPHY_API_KEY = "jGyBAGdeBLXU4WHoAkYF0HxqEFQx2CMa";

// this is how many GIFs 🖼️ will be requested from the API at one time
const int SEARCH_OFFSET = 10;

void main() {
  runApp(const MyApp());
}

// since we don't have that many states, we can put them all in a single enum
enum ApplicationMode { initial, erroring, waiting, search, lookingAtGIF }

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GIF Applet From Hell',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: '🔥 GIF Applet From Hell 🔥'),
    );
  }
}

// I have no idea what this class does, but I found in the template
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

// this class contains search result data
class SearchResult {
  String previewURL; // this will be shown in the search results
  String fullURL; // this is for the full page view

  SearchResult(this.previewURL, this.fullURL);
}

class _MyHomePageState extends State<MyHomePage> {
  // I hope that this language is single-threaded like JS, otherwise we could
  // get some very ungood concurrency bugs with this setup, i.e. when two
  // threads try to write to these variables at the same time
  int delayedTextUpdates = 0;
  String searchString = "";
  List<SearchResult> searchResults = [];
  int searchOffset = 0;

  ApplicationMode currentMode = ApplicationMode.initial;

  String errorString = "";
  String selectedGIF = "";

  void pullInSomeMoreResults() async {
    String encodedString = Uri.encodeComponent(searchString);

    String requestURL =
        "http://api.giphy.com/v1/gifs/search?api_key=$GIPHY_API_KEY&q=$encodedString&limit=$SEARCH_OFFSET&offset=$searchOffset";

    print("Requesting: $requestURL");

    final requestResponse = await http.get(Uri.parse(requestURL));

    if (requestResponse.statusCode != 200) {
      final statusCode = requestResponse.statusCode;
      print("GIPHY API response code: $statusCode");

      errorString = "Received API error code: $statusCode";

      setState(() {
        currentMode = ApplicationMode.erroring;
      });

      return;
    }

    final allData = json.decode(requestResponse.body) as Map<String, dynamic>;
    final relevantData = allData["data"];

    print("okay parsing nows!!!");

    int previousNumberOfResults = searchResults.length;

    for (int i = 0; i < SEARCH_OFFSET; i++) {
      if (relevantData.length <= i) continue;

      SearchResult newResult = SearchResult(
          relevantData[i]["images"]["preview_gif"]["url"],
          relevantData[i]["images"]["original"]["url"]);

      searchResults.add(newResult);
    }

    int deltaOfResults = searchResults.length - previousNumberOfResults;

    print("Retrieved $deltaOfResults new results!");

    searchOffset += SEARCH_OFFSET;

    setState(() {
      currentMode = ApplicationMode.search;
    });
  }

  void startSearching() async {
    // this method gets called with a delay for every character that is typed
    // into the text box. we only want to run the logic for the last character,
    // so we count up how many times startSearching() will be called in the
    // future and only do logic on the very last call

    if (--delayedTextUpdates > 0) return;

    // we could add more checks. I don't know what we should check for.
    // maybe try checking if string consists of only whitespaces?
    bool isValidString = searchString != "";

    if (!isValidString) {
      print("Search string invalid, not requesting!!!");

      setState(() {
        currentMode = ApplicationMode.initial;
      });

      return;
    }

    // reset the search params and request some more datas from API
    searchOffset = 0;
    searchResults = [];

    pullInSomeMoreResults();
  }

  void lookAtGIF(String gif) {
    selectedGIF = gif;

    setState(() {
      currentMode = ApplicationMode.lookingAtGIF;
    });
  }

  void goBackFromLookingAtGIF() {
    setState(() {
      currentMode = ApplicationMode.search;
    });
  }

  Widget makeSearchBox() {
    return TextField(
      decoration: InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'Enter a search term',
      ),
      onChanged: (text) {
        print('First text field: $text (${text.characters.length})');

        setState(() {
          currentMode = ApplicationMode.waiting;
        });

        delayedTextUpdates++;

        searchString = text;

        Future.delayed(Duration(milliseconds: 1000), () {
          startSearching();
        });
      },
    );
  }

  // I think that the creators of this GUI library did not have this in mind
  // when they designed it, but this works
  List<Widget> makePageBasedOnApplicationModeAndStuff() {
    switch (currentMode) {
      case ApplicationMode.initial:
        return [
          makeSearchBox(),
          const Text(
            'You have to search a GIF before!!! you can do anything',
          )
        ];
      case ApplicationMode.erroring:
        return [
          makeSearchBox(),
          Text(
            errorString,
          )
        ];
      case ApplicationMode.waiting:
        return [
          makeSearchBox(),
          const Text(
            '⌛ We are searching for your GIFs, please wait... ⌛',
          )
        ];
      case ApplicationMode.search:
        final GIFs = searchResults.map((SearchResult result) {
          return IconButton(
              icon: Image.network(result.previewURL, width: 100, height: 100),
              onPressed: () {
                print("Pressed on the button!");
                print(result.fullURL);

                lookAtGIF(result.fullURL);
              });
          //return Text(result.previewURL);
        }).toList();

        return [
          makeSearchBox(),
          const Text(
            "Okay, here's your GIFs:",
          ),
          GridView.count(
              physics: NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              crossAxisCount: 3,
              children: GIFs),
          TextButton(
              child: Text("Load some more GIFs 🚀"),
              onPressed: () {
                pullInSomeMoreResults();

                setState(() {
                  currentMode = ApplicationMode.waiting;
                });
              })
        ];
      case ApplicationMode.lookingAtGIF:
        return [
          const Text(
            "🧐 Check this out:",
          ),
          Image.network(selectedGIF),
          TextButton(
              child: const Text(
                "Okey, 😇 I have seen enough..",
              ),
              onPressed: () {
                goBackFromLookingAtGIF();
              })
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: SingleChildScrollView(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: makePageBasedOnApplicationModeAndStuff(),
        )),
      ),
    );
  }
}
