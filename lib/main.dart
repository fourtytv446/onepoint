import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:onepointapp/challengemode.dart';
import 'package:onepointapp/endlessmode.dart';
import 'package:onepointapp/app_localizations.dart';
import 'package:onepointapp/firebase_options.dart';
import 'package:onepointapp/localmultisetup.dart';
import 'package:onepointapp/loginscreen.dart';
import 'package:onepointapp/practice_mode.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onepointapp/settings_screen.dart';
import 'auth_service.dart';
import 'scoreboard.dart';
//import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Platform-specific settings
    if (!kIsWeb) {
      if (Platform.isAndroid) {
        FirebaseDatabase.instance.setPersistenceCacheSizeBytes(10000000);
      }
    }
    runApp(const MyApp());
  } catch (e, s) {
    print('Firebase initialization error: $e\n$s');
    runApp(const MyApp());
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

enum GameMode { endless, challenge }

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('en');

  void _changeLanguage(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '1Point',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 3, 163, 184),
        ),
        fontFamily: 'Prompt',
        useMaterial3: true,
      ),
      locale: _locale,
      supportedLocales: const [Locale('en'), Locale('th')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: HomePage(changeLanguage: _changeLanguage),
    );
  }
}

class HomePage extends StatefulWidget {
  final Function(Locale) changeLanguage;

  const HomePage({super.key, required this.changeLanguage});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isChallengeModeUnlocked = false;
  String t(String key) {
    final localizations = AppLocalizations.of(context);
    // If localizations are not ready, return the key as a fallback.
    if (localizations == null) {
      // This can happen on the first frame while localizations are loading.
      return key;
    }
    // If a key is not found, return the key itself.
    return localizations.translate(key) ?? key;
  }

  @override
  void initState() {
    super.initState();
    _checkChallengeModeStatus();
  }

  Future<void> _checkChallengeModeStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final challengeModeStatus =
          prefs.getBool('challengeModeUnlocked') ?? false;

      if (mounted) {
        // Ensures the widget is still in the widget tree
        setState(() {
          isChallengeModeUnlocked = challengeModeStatus;
        });
      }
    } catch (e) {
      print("Error loading SharedPreferences: $e");
    }
  }

  void _updateChallengeModeStatus() {
    setState(() {
      isChallengeModeUnlocked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color.fromARGB(0, 0, 14, 69),
      // The AppBar will now automatically include a hamburger icon to open the drawer.
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: const Color.fromARGB(0, 0, 38, 143),
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text(t('select_language')),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: const Text('English'),
                          onTap: () {
                            widget.changeLanguage(const Locale('en'));
                            Navigator.of(context).pop();
                          },
                        ),
                        ListTile(
                          title: const Text('ไทย'),
                          onTap: () {
                            widget.changeLanguage(const Locale('th'));
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.login),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Login feature coming soon!',
                    style: const TextStyle(
                      color: Color.fromARGB(255, 0, 247, 255),
                    ),
                  ),
                  backgroundColor: const Color.fromARGB(180, 3, 3, 3),

                  duration: const Duration(seconds: 2),
                ),
              );
              /* Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      Loginscreen(changeLanguage: widget.changeLanguage),
                ),
              ); 
              */
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    onSpeedChanged: (newSpeed) {
                      // No practice speed on home screen, so do nothing.
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
              leading: const Icon(Icons.score),
              title: Text(t('view_leaderboard')),
              onTap: () {
                Navigator.pop(context); // Close the drawer
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
                      Navigator.pop(context); // Close the drawer
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
                Navigator.pop(context); // Close the drawer
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
              title: const Text('Privacy Policy'),
              onTap: () {
                launchUrl(
                  Uri.parse(
                    'https://sites.google.com/view/1pointapp-privacypolicy/home?authuser=0',
                  ),
                );
              },
            ),
          ],
        ),
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

          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/1pointplainlogo.png', height: 200),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      side: const BorderSide(
                        color: Color.fromARGB(255, 0, 195, 255), // Border color
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
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EndlessModeScreen(
                            gameMode: GameMode.endless,
                            changeLanguage: widget.changeLanguage,
                            onChallengeUnlocked: _updateChallengeModeStatus,
                          ),
                        ),
                      );
                    },
                    child: Text(t('start_endless_mode')),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      side: const BorderSide(
                        color: Color.fromARGB(255, 0, 195, 255), // Border color
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
                    onPressed: isChallengeModeUnlocked
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
                                backgroundColor: const Color.fromARGB(
                                  180,
                                  244,
                                  1,
                                  1,
                                ),
                              ),
                            );
                          },
                    child: Text(t('start_challenge_mode')),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      side: const BorderSide(
                        color: Color.fromARGB(255, 0, 195, 255), // Border color
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
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LeaderboardScreen(),
                        ),
                      );
                    },
                    child: Text(t('view_leaderboard')),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      side: const BorderSide(
                        color: Color.fromARGB(255, 0, 195, 255), // Border color
                        width: 0.5, // Border width
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0),
                        // Rounded corners
                      ),

                      backgroundColor: const Color.fromARGB(
                        202,
                        0,
                        0,
                        0,
                      ), // Background color
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Multiplayer coming soon!',
                            style: const TextStyle(
                              color: Color.fromARGB(255, 0, 247, 255),
                            ),
                          ),
                          backgroundColor: const Color.fromARGB(180, 3, 3, 3),

                          duration: const Duration(seconds: 2),
                        ),
                      );
                      /*  Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GameSetupScreen(
                            changeLanguage: widget.changeLanguage,
                          ),
                        ),
                      );  */
                    },
                    child: Text(
                      t('multiplayer'),
                      style: const TextStyle(
                        fontFamily: 'Prompt',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
