import 'package:flutter/material.dart';
import 'package:onepointapp/app_localizations.dart';
import 'package:onepointapp/localmultiplayer.dart';

class GameSetupScreen extends StatefulWidget {
  final Function(Locale) changeLanguage;

  const GameSetupScreen({super.key, required this.changeLanguage});

  @override
  _GameSetupScreenState createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends State<GameSetupScreen> {
  int targetScore = 3;
  String player1Name = "Player 1";
  String player2Name = "Player 2";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000E45),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: const Color.fromARGB(255, 255, 255, 255),
        title: Text(
          AppLocalizations.of(context)!.translate('game_setup') ?? 'Game Setup',
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/bg.png"), // Your image path
            fit: BoxFit.cover, // Ensures the image covers the whole background
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            0,
            20,
            0,
          ), // Removed hardcoded top padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Target Score:',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
              DropdownButton<int>(
                dropdownColor: const Color.fromARGB(199, 0, 55, 92),
                value: targetScore,
                items: [3, 5, 7, 10].map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(
                      '$value points',
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    targetScore = newValue!;
                  });
                },
              ),
              const SizedBox(height: 20),
              TextField(
                style: const TextStyle(
                  fontSize: 16,
                  color: Color.fromARGB(255, 255, 251, 0),
                ),
                decoration: const InputDecoration(
                  labelText: 'Player 1 Name',
                  labelStyle: TextStyle(fontSize: 16, color: Colors.white),
                ),
                onChanged: (value) {
                  setState(() {
                    player1Name = value;
                  });
                },
              ),
              TextField(
                style: const TextStyle(
                  fontSize: 16,
                  color: Color.fromARGB(255, 255, 251, 0),
                ),
                decoration: const InputDecoration(
                  labelText: 'Player 2 Name',
                  labelStyle: TextStyle(fontSize: 16, color: Colors.white),
                ),
                onChanged: (value) {
                  setState(() {
                    player2Name = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                child: const Text('Start Game'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MultiplayerGameScreen(
                        targetScore: targetScore,
                        player1Name: player1Name,
                        player2Name: player2Name,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
