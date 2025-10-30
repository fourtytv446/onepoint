import 'dart:ui';

import 'package:flutter/material.dart';
import 'dart:async'; // Add this line
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:onepointapp/app_localizations.dart';
import 'package:onepointapp/main.dart';
import 'package:onepointapp/practice_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:onepointapp/scoreboard.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'challengemode.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:onepointapp/settings_screen.dart';
//import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'firebase_options.dart';

class EndlessModeScreen extends StatefulWidget {
  final GameMode gameMode;
  final Function(Locale) changeLanguage;
  final VoidCallback onChallengeUnlocked;
  const EndlessModeScreen({
    super.key,
    required this.gameMode,
    required this.changeLanguage, // Add the function parameter
    required this.onChallengeUnlocked,
  });

  @override
  _EndlessModeScreenState createState() => _EndlessModeScreenState();
}

class _EndlessModeScreenState extends State<EndlessModeScreen> {
  double barValue = 0.0;
  bool isPlaying = false;
  int lives = 5;
  int score = 0;
  Timer? timer;
  int currentSpeed = 0;
  // ignore: unused_field
  int _lastUpdateTime = 0;
  Duration nextLifeDuration = const Duration(hours: 0, minutes: 10);
  final AudioPlayer _startButtonPlayer = AudioPlayer();
  final AudioPlayer _stopButtonPlayer = AudioPlayer();
  final AudioPlayer _winPlayer = AudioPlayer();
  final AudioPlayer _gameoverPlayer = AudioPlayer();
  String message = '';
  Timer? _livesTimer;
  bool isSoundOn = true;
  late StreamSubscription<bool> keyboardSubscription;
  Timer? _syncTimer;
  String? _userId;
  bool isChallengeModeUnlocked = false;
  FirebaseDatabase database = FirebaseDatabase.instance;
  //RewardedAd? _rewardedAd;
  bool _isRewardedAdReady = false;

  // IMPORTANT: Replace with your own Ad Unit ID from AdMob
  // This is a test ID provided by Google.
  final String _rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

  String t(String key, [Map<String, dynamic>? params]) {
    String translation = AppLocalizations.of(context)!.translate(key)!;

    if (params != null) {
      params.forEach((key, value) {
        translation = translation.replaceAll('{$key}', value.toString());
      });
    }

    return translation;
  }

  Future<void> _initializeFirebase() async {
    try {
      // Initialize Firebase if not already initialized
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      // Get current user ID or create anonymous session
      User? currentUser = FirebaseAuth.instance.currentUser;
      _userId = currentUser?.uid ?? await _createAnonymousSession();

      if (_userId != null) {
        _setupRealtimeSync();
        _startPeriodicSync();
      }
    } catch (e) {
      print('Firebase initialization error: $e');
      // Handle the error gracefully
      setState(() {
        // Set up offline mode or fallback behavior
        _userId = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('firebase_connection_error')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  late final KeyboardVisibilityController _keyboardController;
  bool _isExternalKeyboardConnected = false;
  bool _isKeyboardPlatform = false;

  late FocusNode _focusNode;
  Future<String> _createAnonymousSession() async {
    final userCredential = await FirebaseAuth.instance.signInAnonymously();
    return userCredential.user!.uid;
  }

  void _setupRealtimeSync() {
    _database.child('users/$_userId/gameState').onValue.listen((event) {
      if (!mounted) return;

      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          lives = data['lives'] ?? 0;
          _lastUpdateTime =
              data['lastUpdateTime'] ?? DateTime.now().millisecondsSinceEpoch;

          // Calculate next life timer
          int millisElapsed =
              DateTime.now().millisecondsSinceEpoch - _lastUpdateTime;
          nextLifeDuration = Duration(
            milliseconds: (600000 - millisElapsed % 600000),
          );
        });
      }
    });
  }

  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _syncGameState();
    });
  }

  Future<void> _syncGameState() async {
    if (_userId == null || !mounted) return;

    try {
      print('Syncing game state to Firebase for user $_userId...');
      DatabaseReference ref = _database.child('users/$_userId/gameState');

      // Use update() for all platforms. It's safer as it doesn't overwrite
      // the entire node if other fields exist.
      await ref.update({
        'lives': lives,
        'lastUpdateTime': DateTime.now().millisecondsSinceEpoch,
        'score': score,
      });
    } catch (e) {
      print('Error syncing game state: $e');
    }
  }

  Future<void> _saveToLocalStorage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lives', lives);
    await prefs.setInt('lastUpdateTime', DateTime.now().millisecondsSinceEpoch);
    await prefs.setInt('score', score);
  }

  @override
  void initState() {
    super.initState();
    //_loadRewardedAd();
    _initializeFirebase();
    _loadSoundPreference();
    _initializeGameState();
    _checkChallengeModeUnlocked();
    _focusNode = FocusNode();
    _checkKeyboardPlatform();
    _keyboardController = KeyboardVisibilityController();
    HardwareKeyboard.instance.addHandler(_handleKeyboardEvent);
    keyboardSubscription = _keyboardController.onChange.listen((
      bool isVisible,
    ) {
      if (Platform.isAndroid || Platform.isIOS) {
        // Only for mobile devices
        setState(() {
          if (isVisible && _isExternalKeyboardConnected) {
            // Show a message when external keyboard is connected
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(t('keyboard_connected')),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  /*
  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          print('$ad loaded.');
          _rewardedAd = ad;
          setState(() {
            _isRewardedAdReady = true;
          });
          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (RewardedAd ad) {
              print('$ad onAdDismissedFullScreenContent.');
              ad.dispose();
              setState(() {
                _isRewardedAdReady = false;
              });
              _loadRewardedAd(); // Pre-load the next ad
            },
            onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
              print('$ad onAdFailedToShowFullScreenContent: $error');
              ad.dispose();
              setState(() {
                _isRewardedAdReady = false;
              });
              _loadRewardedAd(); // Try to load another ad
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('RewardedAd failed to load: $error');
          setState(() {
            _isRewardedAdReady = false;
          });
        },
      ),
    );
  }
*/
  void _checkKeyboardPlatform() {
    if (kIsWeb) {
      setState(() {
        _isKeyboardPlatform = true;
      });
    }
  }

  Future<void> _checkChallengeModeUnlocked() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      isChallengeModeUnlocked = prefs.getBool('challengeModeUnlocked') ?? false;
    });
  }

  bool _handleKeyboardEvent(KeyEvent event) {
    if (event is KeyDownEvent && !_isExternalKeyboardConnected) {
      // Check for hardware keyboard by looking at the device type
      final deviceType = event.deviceType;
      if (deviceType == KeyEventDeviceType.keyboard) {
        setState(() {
          _isExternalKeyboardConnected = true;
        });

        // Show SnackBar only once when the keyboard is first detected
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t('external_keyboard_connected')),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
    // Return false to allow the event to continue to be processed
    return false;
  }

  @override
  void dispose() {
    _livesTimer?.cancel();
    _syncTimer?.cancel();
    // _rewardedAd?.dispose();
    _startButtonPlayer.dispose();
    _stopButtonPlayer.dispose();
    _winPlayer.dispose();
    _gameoverPlayer.dispose();
    _focusNode.dispose();
    keyboardSubscription.cancel();
    ServicesBinding.instance.keyboard.removeHandler(_handleKeyboardEvent);
    super.dispose();
  }

  void _initializeGameState() async {
    if (widget.gameMode == GameMode.endless) {
      await _loadEndlessGameState();
    }
  }

  Future<void> _loadEndlessGameState() async {
    if (_userId != null) {
      final snapshot = await _database
          .child('users/$_userId/gameState')
          .get()
          .catchError((_) => null);

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        int storedLives = data['lives'] ?? 0;
        int lastUpdateTime =
            data['lastUpdateTime'] ?? DateTime.now().millisecondsSinceEpoch;

        _updateGameState(storedLives, lastUpdateTime);
      } else {
        // Fall back to local storage if no Firebase data exists
        await _loadFromLocalStorage();
      }
    } else {
      await _loadFromLocalStorage();
    }
  }

  Future<void> _loadFromLocalStorage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int storedLives = prefs.getInt('lives') ?? 5;
    int lastUpdateTime =
        prefs.getInt('lastUpdateTime') ?? DateTime.now().millisecondsSinceEpoch;

    _updateGameState(storedLives, lastUpdateTime);
  }

  void _updateGameState(int storedLives, int lastUpdateTime) {
    int currentTime = DateTime.now().millisecondsSinceEpoch;
    int millisElapsed = currentTime - lastUpdateTime;
    int minutesElapsed = (millisElapsed / (1000 * 60)).floor();
    int newLives = storedLives + (minutesElapsed ~/ 10);
    if (newLives > 5) newLives = 5;

    setState(() {
      lives = newLives;
      int millisUntilNextLife = (600000 - millisElapsed % 600000);
      nextLifeDuration = Duration(milliseconds: millisUntilNextLife);
      _lastUpdateTime = currentTime;
    });

    _saveLives();
    _startLivesTimer();
  }

  void _startLivesTimer() {
    _livesTimer?.cancel(); // Cancel any existing timer
    _livesTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && widget.gameMode == GameMode.endless) {
        setState(() {
          if (nextLifeDuration.inSeconds > 0) {
            nextLifeDuration -= const Duration(seconds: 1);
          } else {
            if (lives < 5) {
              lives++;
              nextLifeDuration = Duration(minutes: 10);
              _saveLives();
            }
          }
        });
      }
    });
  }

  // Modify existing _saveLives method to include Firebase sync
  Future<void> _saveLives() async {
    if (widget.gameMode == GameMode.endless) {
      // Save locally
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt('lives', lives);
      await prefs.setInt(
        'lastUpdateTime',
        DateTime.now().millisecondsSinceEpoch,
      );

      // Sync with Firebase
      await _syncGameState();
    }
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

      currentSpeed = Random().nextInt(81) + 20; // 5 to 50 ms
      _saveLives();
    });
    timer = Timer.periodic(Duration(milliseconds: currentSpeed), (timer) {
      setState(() {
        barValue += 0.01;
        if (barValue > 1.99) {
          stopGame(true);
        }
      });
    });
  }

  Future<void> _unlockChallengeMode() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('challengeModeUnlocked', true);
    widget.onChallengeUnlocked();
    // Notify the user that Challenge Mode is unlocked
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Challenge Mode Unlocked!')));
  }

  Future<void> stopGame(bool userStopped) async {
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
          if (score >= 10 && !isChallengeModeUnlocked) {
            isChallengeModeUnlocked = true;
            _unlockChallengeMode();
          }
          message =
              'Perfect! You stopped at exactly 1.00! Speed was ${currentSpeed}ms';
        });
      } else if (roundedValue > 1.00) {
        _playSound(_gameoverPlayer, 'gameover.wav');
        // In endless mode, player loses a life if they go over 1.00
        setState(() {
          lives--;
          message =
              'Game Over! You stopped at ${roundedValue.toStringAsFixed(2)}. Final score: $score.';
        });

        _gameOver();
      } else {
        // In endless mode, stopping below 1.00 means the player can try again with no life loss
        _playSound(_stopButtonPlayer, '1point bonuspressed.mp3');
        setState(() {
          message =
              'Missed! You stopped at ${roundedValue.toStringAsFixed(2)}. Try again!';
        });
      }
    }
  }

  void _gameOver() async {
    _playSound(_gameoverPlayer, 'gameover.wav');
    String playerName = await _showGameOverDialog();
  }

  Future<String> _showGameOverDialog() async {
    String playerName = '';
    await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        TextEditingController nameController = TextEditingController();

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
          title: Text(
            t('game_over'),
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color.fromARGB(224, 6, 8, 39),
          shadowColor: const Color.fromARGB(224, 0, 153, 255),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your final score is $score.',
                style: const TextStyle(color: Colors.white),
              ),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: t('Enteryourname'),
                  labelStyle: const TextStyle(color: Colors.white),
                ),
                style: const TextStyle(
                  color: Color.fromARGB(255, 255, 242, 53),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text(t('Save')),
              onPressed: () async {
                playerName = nameController.text.trim();
                if (playerName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(t('Please enter your name.')),
                      backgroundColor: Colors.red,
                    ),
                  );
                } else {
                  Navigator.of(context).pop(playerName);
                }
              },
            ),
          ],
        );
      },
    );

    await _saveScore(score, widget.gameMode, playerName);
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
          backgroundColor: const Color.fromARGB(223, 39, 6, 6),
          shadowColor: const Color.fromARGB(223, 255, 0, 0),
          title: Text(
            t('game_over'),
            style: const TextStyle(color: Color.fromARGB(255, 255, 50, 14)),
          ),
          content: Text(
            '$playerName, your final score is $score.',
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              child: Text(t('ViewLeaderboard')),
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
              child: Text(t('Close')),
              onPressed: () {
                Navigator.of(context).pop();

                // Return to HomePage
              },
            ),
          ],
        ),
      );
    }
    // Reset the score after saving it
    setState(() {
      score = 0;
    });

    return playerName.isNotEmpty ? playerName : 'Player';
  }

  Future<void> _saveScore(int score, GameMode mode, String playerName) async {
    // --- Save to Firebase Realtime Database ---
    if (_userId != null) {
      try {
        DatabaseReference leaderboardRef = _database.child(
          'leaderboard/endless',
        );
        String entryId = leaderboardRef.push().key!; // Generate a unique key
        await leaderboardRef.child(entryId).set({
          'name': playerName,
          'score': score,
          'timestamp': DateTime.now().toIso8601String(),
          'userId': _userId,
        });
        print('Score saved to Firebase leaderboard.');
      } catch (e) {
        print('Error saving score to Firebase: $e');
      }
    }

    // --- Save to local SharedPreferences (as a backup or for local display) ---
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> leaderboard = prefs.getStringList('endlessLeaderboard') ?? [];
    String currentDateTime = DateTime.now().toIso8601String();
    leaderboard.add('$playerName,$score,$currentDateTime');
    await prefs.setStringList('endlessLeaderboard', leaderboard);
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
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
        title: Text(t('title_endless')),
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
                      // Endless mode doesn't use practiceSpeed, so do nothing.
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
              decoration: BoxDecoration(color: Color.fromARGB(199, 0, 69, 160)),
              child: Text(
                '1Point Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: Text(t('Home')),
              onTap: () {
                // Navigate to Scoreboard
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
            ListTile(
              leading: const Icon(Icons.score),
              title: Text(t('view_leaderboard')),
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
              leading: const Icon(Icons.flag),
              title: Text(t('start_challenge_mode')),
              onTap: isChallengeModeUnlocked
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChallengeModeScreen(
                            gameMode: GameMode.challenge,
                            changeLanguage: widget.changeLanguage,
                          ),
                        ),
                      );
                    }
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(t('unlockchallengealert')),
                          backgroundColor: const Color.fromARGB(180, 244, 1, 1),
                        ),
                      );
                    },
              enabled: isChallengeModeUnlocked, // Grey out if not unlocked
            ),
            ListTile(
              leading: const Icon(Icons.fitness_center),
              title: Text(t('Practice')),
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
            ListTile(
              leading: const Icon(Icons.policy),
              title: Text('Privacy Policy'),
              onTap: () async {
                // --- Replace with your actual Privacy Policy URL ---
                final Uri url = Uri.parse(
                  'https://sites.google.com/view/1pointapp-privacypolicy/home?authuser=0',
                );
                if (!await launchUrl(url)) {
                  // Show an error if the URL can't be launched
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Could not launch ${url.toString()}'),
                      ),
                    );
                  }
                }
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
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 75, 20, 0),
                      child: Column(
                        children: [
                          if (widget.gameMode == GameMode.endless)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: List.generate(
                                    5,
                                    (index) => Icon(
                                      Icons.favorite,
                                      color: index < lives
                                          ? Colors.red
                                          : Colors.grey,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  lives < 5
                                      ? _formatDuration(nextLifeDuration)
                                      : t('full'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // To re-enable rewarded ads for lives, comment out the IconButton below
                                // and uncomment the one after it.
                                IconButton(
                                  icon: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      if (lives < 5) lives++;
                                    });
                                  },
                                ),
                                /*
                                IconButton(
                                  icon: Icon(
                                    Icons.slow_motion_video,
                                    color: _isRewardedAdReady && lives < 5
                                        ? Colors.greenAccent
                                        : Colors.grey,
                                  ),
                                  onPressed: () {
                                    if (!_isRewardedAdReady || lives >= 5) {
                                      return;
                                    }
                                    _rewardedAd?.show(
                                      onUserEarnedReward:
                                          (ad, reward) {
                                        print(
                                          'Reward earned: ${reward.amount} ${reward.type}',
                                        );
                                        setState(() {
                                          if (lives < 5) lives++;
                                        });
                                        _saveLives(); // Save the new life count
                                      },
                                    );
                                  },
                                ),
                                */
                              ],
                            ),
                          const Flexible(flex: 1, child: SizedBox()),
                          Text(
                            'Score: $score',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                            ),
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
                            t('timeToReach', {
                              'time': (currentSpeed / 10).toString(),
                            }),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                            ),
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
                          const Flexible(flex: 1, child: SizedBox(height: 20)),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              side: const BorderSide(
                                color: Color.fromARGB(
                                  255,
                                  0,
                                  195,
                                  255,
                                ), // Border color
                                width: 0.5, // Border width
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(0),
                                // Rounded corners
                              ),
                              textStyle: const TextStyle(
                                fontFamily: 'Prompt',
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              backgroundColor: const Color.fromARGB(
                                202,
                                0,
                                0,
                                0,
                              ), // Background color
                              foregroundColor: Colors.white,
                            ),
                            onPressed:
                                (widget.gameMode == GameMode.endless &&
                                    lives <= 0)
                                ? null
                                : (isPlaying
                                      ? () => stopGame(true)
                                      : startGame),
                            child: Text(isPlaying ? t('stop') : t('start')),
                          ),
                          Flexible(flex: 1, child: SizedBox(height: 20)),
                          if (_isKeyboardPlatform ||
                              _isExternalKeyboardConnected)
                            Text(
                              t('space_bar_instruction'),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          Flexible(flex: 2, child: SizedBox(height: 20)),
                          Text(
                            (widget.gameMode == GameMode.endless && lives <= 0)
                                ? t('noLives')
                                : message,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
