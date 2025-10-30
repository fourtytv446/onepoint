import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:onepointapp/app_localizations.dart';

class MultiplayerGameScreen extends StatefulWidget {
  final int targetScore;
  final String player1Name;
  final String player2Name;

  const MultiplayerGameScreen({
    super.key,
    required this.targetScore,
    required this.player1Name,
    required this.player2Name,
  });

  @override
  _MultiplayerGameScreenState createState() => _MultiplayerGameScreenState();
}

class _MultiplayerGameScreenState extends State<MultiplayerGameScreen> {
  double barValue = 0.0;
  bool isPlaying = false;
  int player1Score = 0;
  int player2Score = 0;
  int currentPlayer = 1;
  Timer? timer;
  int currentSpeed = 0;
  final AudioPlayer _buttonPlayer = AudioPlayer();
  String message = '';
  double player1LastScore = 0.0;
  double player2LastScore = 0.0;
  String t(String key, [Map<String, dynamic>? params]) {
    String translation = AppLocalizations.of(context)!.translate(key)!;

    if (params != null) {
      params.forEach((key, value) {
        translation = translation.replaceAll('{$key}', value.toString());
      });
    }

    return translation;
  }

  @override
  void initState() {
    super.initState();
    currentSpeed = Random().nextInt(81) + 20; // 20 to 100 ms
  }

  void startGame() {
    if (isPlaying) return;
    setState(() {
      isPlaying = true;
      barValue = 0.0;
      message =
          Text(t("currentPlayer", {'currentPlayer': currentPlayer})) as String;
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

  void stopGame(bool automatic) {
    if (!isPlaying) return;
    timer?.cancel();
    setState(() {
      isPlaying = false;
    });

    double roundedValue = (barValue * 100).round() / 100;

    if (currentPlayer == 1) {
      player1LastScore = roundedValue;
      if (roundedValue > 1.00) {
        message = '${widget.player1Name} went over 1.00!';
      } else {
        message = '${widget.player1Name} scored $roundedValue';
      }
      currentPlayer = 2;
    } else {
      player2LastScore = roundedValue;
      if (roundedValue > 1.00 || roundedValue <= player1LastScore) {
        message = '${widget.player1Name} wins this round!';
        player1Score++;
      } else if (roundedValue == 1.00) {
        message = '${widget.player2Name} wins with a perfect 1.00!';
        player2Score++;
      } else {
        message = '${widget.player2Name} wins this round!';
        player2Score++;
      }
      currentPlayer = 1;
      player1LastScore = 0.0;
      player2LastScore = 0.0;
    }

    if (player1Score >= widget.targetScore ||
        player2Score >= widget.targetScore) {
      _gameOver();
    }

    setState(() {});
  }

  void _gameOver() {
    String winner = player1Score > player2Score
        ? widget.player1Name
        : widget.player2Name;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(t("game_over")),
          content: Text(t('Winner', {'winner': winner})),
          actions: <Widget>[
            TextButton(
              child: Text(t('playAgain')),
              onPressed: () {
                Navigator.of(context).pop();
                _resetGame();
              },
            ),
            TextButton(
              child: Text(t("mainMenu")),
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ],
        );
      },
    );
  }

  void _resetGame() {
    setState(() {
      player1Score = 0;
      player2Score = 0;
      currentPlayer = 1;
      player1LastScore = 0.0;
      player2LastScore = 0.0;
      barValue = 0.0;
      isPlaying = false;
      message = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF000E45),
      appBar: AppBar(
        title: const Text('Multiplayer Game'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                '${widget.player1Name}: $player1Score | ${widget.player2Name}: $player2Score',
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Container(
                width: 60,
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue, width: 2),
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
                style: const TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isPlaying ? () => stopGame(false) : startGame,
                child: Text(isPlaying ? 'Stop' : 'Start'),
              ),
              const SizedBox(height: 20),
              Text(
                message,
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBarColor() {
    return Color.lerp(Colors.yellow, Colors.red, min(barValue, 1))!;
  }
}
