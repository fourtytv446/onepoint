import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:onepointapp/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PracticeModeScreen extends StatefulWidget {
  final Function(Locale) changeLanguage;

  const PracticeModeScreen({super.key, required this.changeLanguage});

  @override
  _PracticeModeScreenState createState() => _PracticeModeScreenState();
}

class _PracticeModeScreenState extends State<PracticeModeScreen>
    with WidgetsBindingObserver {
  double barValue = 0.0;
  bool isPlaying = false;
  Timer? timer;
  int practiceSpeed = 50; // Default speed
  final AudioPlayer _startButtonPlayer = AudioPlayer();
  final AudioPlayer _stopButtonPlayer = AudioPlayer();
  final AudioPlayer _winPlayer = AudioPlayer();
  String message = '';
  bool isSoundOn = true;
  late FocusNode _focusNode;
  @override
  void initState() {
    super.initState();
    _loadSettings();
    WidgetsBinding.instance.addObserver(this);
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _startButtonPlayer.dispose();
    _stopButtonPlayer.dispose();
    _winPlayer.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadSettings();
    }
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      practiceSpeed = prefs.getInt('practiceSpeed') ?? 50;
      isSoundOn = prefs.getBool('isSoundOn') ?? true;
    });
  }

  void startGame() {
    if (isPlaying) return;
    _playSound(_startButtonPlayer, '1point bonussound.mp3');
    setState(() {
      isPlaying = true;
      barValue = 0.0;
      message = 'Try to stop at exactly 1.00!';
    });
    timer = Timer.periodic(Duration(milliseconds: practiceSpeed), (timer) {
      setState(() {
        barValue += 0.01;
        if (barValue > 1.99) {
          stopGame(true);
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
        _playSound(_winPlayer, 'win.mp3');
        setState(() {
          message = 'Perfect! You stopped at exactly 1.00!';
        });
      } else if (roundedValue > 1.00) {
        _playSound(_stopButtonPlayer, '1point bonuspressed.mp3');
        setState(() {
          message = 'Oops! You went over 1.00. Try again!';
        });
      } else {
        _playSound(_stopButtonPlayer, '1point bonuspressed.mp3');
        setState(() {
          message =
              'Almost! You stopped at ${roundedValue.toStringAsFixed(2)}. Try again!';
        });
      }
    }
  }

  Future<void> _playSound(AudioPlayer player, String asset) async {
    if (isSoundOn) {
      await player.play(AssetSource(asset));
    }
  }

  Color _getBarColor() {
    return Color.lerp(Colors.yellow, Colors.red, min(barValue, 1))!;
  }

  Color _getValueColor() {
    double roundedValue = (barValue * 100).round() / 100;
    if (roundedValue > 1.00) {
      return Colors.red;
    } else if (roundedValue == 1.00) {
      return Colors.green;
    } else {
      return const Color.fromARGB(255, 255, 255, 255);
    }
  }

  void _toggleSound() async {
    setState(() {
      isSoundOn = !isSoundOn;
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isSoundOn', isSoundOn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color.fromARGB(155, 0, 20, 102),
      appBar: AppBar(
        title: const Text('Practice'),
        foregroundColor: Colors.white,
        backgroundColor: const Color.fromARGB(0, 0, 38, 143),
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
                      setState(() {
                        practiceSpeed = newSpeed; // Update speed immediately
                      });
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: KeyboardListener(
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
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Removed const SizedBox(height: 50), as SafeArea handles top padding
                          Container(
                            width: 60,
                            height: 300,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00268F),
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
                          const SizedBox(height: 20),
                          Text(
                            barValue.toStringAsFixed(2),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _getValueColor(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Speed: $practiceSpeed ms',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: isPlaying
                                ? () => stopGame(true)
                                : startGame,
                            child: Text(isPlaying ? 'Stop' : 'Start'),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            message,
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
