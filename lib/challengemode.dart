import 'package:flutter/material.dart';
import 'dart:async'; // Add this line
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:onepointapp/app_localizations.dart';
import 'package:onepointapp/main.dart';
import 'package:onepointapp/practice_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onepointapp/settings_screen.dart';

import 'package:onepointapp/scoreboard.dart';

class ChallengeModeScreen extends StatefulWidget {
  final GameMode gameMode;
  final Function(Locale) changeLanguage;
  const ChallengeModeScreen({
    super.key,
    required this.gameMode,
    required this.changeLanguage, // Add the function parameter
  });

  @override
  _ChallengeModeScreenState createState() => _ChallengeModeScreenState();
}

class _ChallengeModeScreenState extends State<ChallengeModeScreen> {
  double barValue = 0.0;
  bool isPlaying = false;
  int lives = 0;
  int score = 0;
  Timer? timer;
  int currentSpeed = 0;
  // ignore: unused_field

  final AudioPlayer _startButtonPlayer = AudioPlayer();
  final AudioPlayer _stopButtonPlayer = AudioPlayer();
  final AudioPlayer _winPlayer = AudioPlayer();
  final AudioPlayer _gameoverPlayer = AudioPlayer();
  String message = '';
  bool isSoundOn = true;
  late FocusNode _focusNode;

  String t(String key) {
    return AppLocalizations.of(context)!.translate(key)!;
  }

  @override
  void initState() {
    super.initState();
    _loadSoundPreference();
    _initializeGameState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  void dispose() {
    _startButtonPlayer.dispose();
    _stopButtonPlayer.dispose();
    _winPlayer.dispose();
    _gameoverPlayer.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _initializeGameState() async {
    if (widget.gameMode == GameMode.challenge) {
      _initializeChallengeMode();
    }
  }

  void _initializeChallengeMode() {
    setState(() {
      currentSpeed = 100; // Set initial speed to 100ms for challenge mode
    });
  }

  Future<void> _playSound(AudioPlayer player, String asset) async {
    if (isSoundOn) {
      await player.play(AssetSource(asset));
    }
  }

  void startGame() {
    if (isPlaying || (widget.gameMode == GameMode.endless && lives <= 0)) {
      return;
    }
    _playSound(_startButtonPlayer, '1point bonussound.mp3');
    message = t('try_to_get_exactly');
    setState(() {
      isPlaying = true;
      barValue = 0.0;
    });
    timer = Timer.periodic(Duration(milliseconds: currentSpeed), (timer) {
      setState(() {
        barValue += 0.01;
        if (barValue > 1.5) {
          stopGame(false);
        }
      });
    });
  }

  void stopGame(bool userStopped) {
    if (userStopped) {
      if (_startButtonPlayer.state == PlayerState.playing) {
        _startButtonPlayer.stop();
      }
      timer?.cancel();
      setState(() {
        isPlaying = false;
      });

      double roundedValue = (barValue * 100).round() / 100;

      if (roundedValue == 1.00) {
        // Player stopped at exactly 1.00 in both modes
        _playSound(_winPlayer, 'win.mp3');
        setState(() {
          score++;
          message = t('perfect');
          currentSpeed = max(
            20,
            currentSpeed - 5,
          ); // Decrease speed, minimum 20ms
        });
      } else if (roundedValue > 1.00) {
        _playSound(_gameoverPlayer, 'gameover.wav');
        // In challenge mode, going over 1.00 is an immediate game over
        message = t('game_over');
        _gameOver(); // Trigger game over immediately in challenge mode
      } else {
        _playSound(_gameoverPlayer, 'gameover.wav');
        // In challenge mode, missing is an immediate game over
        message = t('game_over');

        _gameOver();
      }
    }
  }

  void _gameOver() {
    _playSound(_gameoverPlayer, 'gameover.wav');
    _showGameOverDialog();
  }

  Future<void> _showGameOverDialog() async {
    String playerName = '';
    await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        TextEditingController nameController = TextEditingController();

        return AlertDialog(
          title: const Text('Game Over'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Your final score is $score.'),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Enter your name'),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                playerName = nameController.text.trim();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );

    if (playerName.isNotEmpty) {
      await _saveScore(score, widget.gameMode, playerName);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Game Over'),
          content: Text('$playerName, your final score is $score.'),
          actions: [
            TextButton(
              child: const Text('View Leaderboard'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LeaderboardScreen(),
                  ),
                );
              },
            ),
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );

      // Reset the score after saving it
      setState(() {
        score = 0;
      });
    }
  }

  Future<void> _saveScore(int score, GameMode mode, String playerName) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> leaderboard =
        prefs.getStringList('challengeLeaderboard') ?? [];
    String currentDateTime = DateTime.now().toIso8601String();
    leaderboard.add('$playerName,$score,$currentDateTime');
    await prefs.setStringList('challengeLeaderboard', leaderboard);
  }

  Color _getBarColor() {
    return Color.lerp(
      Colors.yellow,
      const Color.fromARGB(255, 255, 103, 2),
      min(barValue, 1),
    )!;
  }

  Color _getValueColor() {
    double roundedValue = (barValue * 100).round() / 100;
    if (roundedValue > 1.00) {
      return Colors.red;
    } else if (roundedValue == 1.00) {
      return Colors.green;
    } else {
      return const Color.fromARGB(255, 255, 251, 0);
    }
  }

  Future<void> _loadSoundPreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      isSoundOn = prefs.getBool('isSoundOn') ?? true;
    });
  }

  Future<void> _toggleSound() async {
    setState(() {
      isSoundOn = !isSoundOn;
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isSoundOn', isSoundOn);
    if (!isSoundOn) {
      _startButtonPlayer.stop();
      _stopButtonPlayer.stop();
      _winPlayer.stop();
      _gameoverPlayer.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF000E45),
      appBar: AppBar(
        title: Text(t('title_challenge')),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(isSoundOn ? Icons.volume_up : Icons.volume_off),
            onPressed: _toggleSound,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    onSpeedChanged: (newSpeed) {
                      // Challenge mode doesn't use practiceSpeed, so do nothing.
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF00268F)),
              child: Text(
                '1Point Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () {
                // Navigate to Scoreboard
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        HomePage(changeLanguage: widget.changeLanguage),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.score),
              title: const Text('Scoreboard'),
              onTap: () {
                // Navigate to Scoreboard
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LeaderboardScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                // Navigate to Settings
                Navigator.pop(context);
                // TODO: Implement navigation to Settings
              },
            ),
            ListTile(
              leading: const Icon(Icons.fitness_center),
              title: const Text('Practice'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PracticeModeScreen(
                      changeLanguage: widget.changeLanguage,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/bg.png"), // Your image path
            fit: BoxFit.cover, // Ensures the image covers the whole background
          ),
        ),
        child: KeyboardListener(
          focusNode: _focusNode,
          onKeyEvent: (KeyEvent event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.space) {
                if (isPlaying) {
                  stopGame(true);
                } else {
                  startGame();
                }
              }
            }
          },
          child: Center(
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage("assets/bg.png"), // Your image path
                    fit: BoxFit
                        .cover, // Ensures the image covers the whole background
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 10),
                        Text(
                          'Accuracy is king!!!',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ],
                    ),
                    const Flexible(flex: 1, child: SizedBox()),
                    Text(
                      'Score: $score',
                      style: const TextStyle(fontSize: 18, color: Colors.white),
                    ),
                    const Flexible(flex: 1, child: SizedBox()),
                    Container(
                      width: 60,
                      height: 300,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF00D9FF),
                          width: 2,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 300 * barValue,
                            child: Container(color: _getBarColor()),
                          ),
                        ],
                      ),
                    ),
                    const Flexible(flex: 1, child: SizedBox()),
                    Text(
                      'จะถึง 1.00 ใน ${currentSpeed / 10} วินาที',
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    const Flexible(flex: 1, child: SizedBox()),
                    Text(
                      barValue.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _getValueColor(),
                      ),
                    ),
                    const Flexible(flex: 1, child: SizedBox()),
                    ElevatedButton(
                      onPressed:
                          (widget.gameMode == GameMode.endless && lives <= 0)
                          ? null
                          : (isPlaying ? () => stopGame(true) : startGame),
                      child: Text(
                        isPlaying
                            ? AppLocalizations.of(context)!.translate('stop') ??
                                  'Stop'
                            : AppLocalizations.of(
                                    context,
                                  )!.translate('start') ??
                                  'Start',
                      ),
                    ),
                    const Flexible(flex: 1, child: SizedBox()),
                    const Text(
                      'For Keyboard Users, Press SPACE to start/stop',
                      style: TextStyle(fontSize: 14, color: Colors.white),
                    ),
                    const Flexible(flex: 1, child: SizedBox()),
                    Text(
                      (widget.gameMode == GameMode.endless && lives <= 0)
                          ? AppLocalizations.of(
                                  context,
                                )!.translate('noLives') ??
                                'No lives left. Wait for recovery or add more lives.'
                          : message,
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
