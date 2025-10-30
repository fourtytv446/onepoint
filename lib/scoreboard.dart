import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // Import for date formatting
import 'package:onepointapp/main.dart';

enum SortOption { score, name, date }

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _LeaderboardScreenState createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<String> _endlessLeaderboard = [];
  List<String> _challengeLeaderboard = [];
  int _recordsToShow = 10;
  final int _maxRecordsToShow = 50;
  int _customDurationDays = 90;
  SortOption _currentSortOption = SortOption.score;
  bool _sortAscending = false;
  GameMode _currentGameMode = GameMode.endless;

  @override
  void initState() {
    super.initState();
    _loadLeaderboards();
    _loadCustomDuration();
    _loadRecordsToShow(); // Add this method to load the saved value
  }

  Future<void> _loadRecordsToShow() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _recordsToShow = prefs.getInt('recordsToShow') ?? 10;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadLeaderboards() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> endlessLeaderboard =
        prefs.getStringList('endlessLeaderboard') ?? [];
    List<String> challengeLeaderboard =
        prefs.getStringList('challengeLeaderboard') ?? [];

    // Filter out records older than the custom duration
    DateTime now = DateTime.now();
    endlessLeaderboard = _filterLeaderboard(endlessLeaderboard, now);
    challengeLeaderboard = _filterLeaderboard(challengeLeaderboard, now);

    _sortLeaderboard(endlessLeaderboard);
    _sortLeaderboard(challengeLeaderboard);

    setState(() {
      _endlessLeaderboard = endlessLeaderboard;
      _challengeLeaderboard = challengeLeaderboard;
    });
  }

  List<String> _filterLeaderboard(List<String> leaderboard, DateTime now) {
    return leaderboard.where((entry) {
      List<String> parts = entry.split(',');
      DateTime recordDate = DateTime.parse(parts[2]);
      return now.difference(recordDate).inDays <= _customDurationDays;
    }).toList();
  }

  void _sortLeaderboard(List<String> leaderboard) {
    leaderboard.sort((a, b) {
      List<String> aParts = a.split(',');
      List<String> bParts = b.split(',');
      int comparison;
      switch (_currentSortOption) {
        case SortOption.score:
          comparison = int.parse(bParts[1]).compareTo(int.parse(aParts[1]));
          break;
        case SortOption.name:
          comparison = aParts[0].compareTo(bParts[0]);
          break;
        case SortOption.date:
          comparison = bParts[2].compareTo(aParts[2]);
          break;
      }
      return _sortAscending ? -comparison : comparison;
    });
  }

  void _changeSortOption(SortOption option) {
    setState(() {
      if (_currentSortOption == option) {
        _sortAscending = !_sortAscending;
      } else {
        _currentSortOption = option;
        _sortAscending = false;
      }
      _sortLeaderboard(
        _currentGameMode == GameMode.endless
            ? _endlessLeaderboard
            : _challengeLeaderboard,
      );
    });
  }

  Future<void> _clearLeaderboard() async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Warning'),
          content: Text(
            'Records older than $_customDurationDays days will be deleted for ${_currentGameMode == GameMode.endless ? "Endless" : "Challenge"} mode. Are you sure you want to continue?',
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () async {
                Navigator.of(context).pop();
                SharedPreferences prefs = await SharedPreferences.getInstance();
                String key = _currentGameMode == GameMode.endless
                    ? 'endlessLeaderboard'
                    : 'challengeLeaderboard';
                List<String> leaderboard = prefs.getStringList(key) ?? [];

                DateTime now = DateTime.now();
                leaderboard = _filterLeaderboard(leaderboard, now);

                await prefs.setStringList(key, leaderboard);
                _loadLeaderboards();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadCustomDuration() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _customDurationDays = prefs.getInt('customDurationDays') ?? 90;
    });
  }

  Future<void> _setCustomDuration() async {
    int? duration = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Custom Duration'),
          content: TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Enter number of days',
            ),
            onSubmitted: (value) {
              Navigator.of(context).pop(int.tryParse(value));
            },
          ),
        );
      },
    );
    if (duration != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt('customDurationDays', duration);
      setState(() {
        _customDurationDays = duration;
      });
    }
  }

  void _showRecordsChoiceDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Show Records'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<int>(
                title: const Text('Show Latest 10 Records'),
                value: 10,
                groupValue: _recordsToShow,
                onChanged: (value) {
                  setState(() {
                    _recordsToShow = value!;
                    if (_recordsToShow > _maxRecordsToShow) {
                      _recordsToShow = _maxRecordsToShow;
                    }
                    Navigator.of(context).pop();
                  });
                },
              ),
              RadioListTile<int>(
                title: const Text('Show Latest 20 Records'),
                value: 20,
                groupValue: _recordsToShow,
                onChanged: (value) {
                  setState(() {
                    _recordsToShow = value!;
                    if (_recordsToShow > _maxRecordsToShow) {
                      _recordsToShow = _maxRecordsToShow;
                    }
                    Navigator.of(context).pop();
                  });
                },
              ),
              RadioListTile<int>(
                title: const Text('Show Latest 50 Records'),
                value: 50,
                groupValue: _recordsToShow,
                onChanged: (value) {
                  setState(() {
                    _recordsToShow = value!;
                    if (_recordsToShow > _maxRecordsToShow) {
                      _recordsToShow = _maxRecordsToShow;
                    }
                    Navigator.of(context).pop();
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDateTime(String dateTimeStr) {
    DateTime dateTime = DateTime.parse(dateTimeStr);
    return DateFormat('yyyy-MM-dd – kk:mm').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    List<String> currentLeaderboard = _currentGameMode == GameMode.endless
        ? _endlessLeaderboard
        : _challengeLeaderboard;
    List<String> displayedLeaderboard = currentLeaderboard
        .take(_recordsToShow)
        .toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Leaderboard'),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color.fromARGB(255, 129, 205, 255),
        actions: [
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            onSelected: _changeSortOption,
            itemBuilder: (BuildContext context) => <PopupMenuEntry<SortOption>>[
              const PopupMenuItem<SortOption>(
                value: SortOption.score,
                child: Text('Sort by Score'),
              ),
              const PopupMenuItem<SortOption>(
                value: SortOption.name,
                child: Text('Sort by Name'),
              ),
              const PopupMenuItem<SortOption>(
                value: SortOption.date,
                child: Text('Sort by Date'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearLeaderboard,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showRecordsChoiceDialog,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _setCustomDuration,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background image that fills the entire screen
          Positioned.fill(
            child: Image.asset(
              'assets/bg.png', // Your background image
              fit: BoxFit.cover, // Fills the whole screen
            ),
          ),
          Positioned.fill(
            child: Column(
              children: [
                SafeArea(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      0,
                    ), // Removed hardcoded top padding
                    color: Colors.transparent,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () => setState(
                            () => _currentGameMode = GameMode.endless,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _currentGameMode == GameMode.endless
                                ? Colors.blue
                                : Colors.grey,
                          ),
                          child: const Text('Endless Mode'),
                        ),
                        ElevatedButton(
                          onPressed: () => setState(
                            () => _currentGameMode = GameMode.challenge,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _currentGameMode == GameMode.challenge
                                ? Colors.blue
                                : Colors.grey,
                          ),
                          child: const Text('Challenge Mode'),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    color: const Color.fromARGB(148, 0, 102, 97),
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      0,
                    ), // Change top padding to 0
                    child: ListView.builder(
                      itemCount: displayedLeaderboard.length,
                      itemBuilder: (context, index) {
                        final entry = displayedLeaderboard[index].split(',');
                        final name = entry[0];
                        final score = entry[1];
                        final dateTime = entry[2];
                        return ListTile(
                          title: Text(
                            '$name: $score',
                            style: const TextStyle(
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          subtitle: Text(
                            'Date: ${_formatDateTime(dateTime)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                              fontSize: 14,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
