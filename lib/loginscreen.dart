import 'package:flutter/material.dart';
import 'package:onepointapp/app_localizations.dart';
import 'auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';

class Loginscreen extends StatefulWidget {
  final Function(Locale) changeLanguage;

  const Loginscreen({super.key, required this.changeLanguage});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<Loginscreen> {
  final TextEditingController controlleremail = TextEditingController();
  final TextEditingController controllerpassword = TextEditingController();
  int targetScore = 3;
  void register() async {
    try {
      await authService.value.registerWithEmailAndPassword(
        controlleremail.text,
        controllerpassword.text,
      );
      Navigator.pop(context); // Close the dialog after registration
    } on FirebaseAuthException catch (e) {
      Fluttertoast.showToast(
        msg: 'Error: ${e.message}',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  void login() async {
    try {
      await authService.value.signInWithEmailAndPassword(
        controlleremail.text,
        controllerpassword.text,
      );
      Navigator.pop(context); // Close the dialog after login
    } on FirebaseAuthException catch (e) {
      Fluttertoast.showToast(
        msg: 'Error: ${e.message}',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000E45),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: const Color.fromARGB(255, 255, 255, 255),
        title: Text(
          AppLocalizations.of(context)!.translate('game_setup') ?? 'Login',
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/bg.png"), // Your image path
            fit: BoxFit.cover, // Ensures the image covers the whole background
          ),
        ),
        child: SafeArea(
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
                const SizedBox(height: 20),
                TextField(
                  controller: controlleremail,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color.fromARGB(255, 255, 251, 0),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-MAIL',
                    labelStyle: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                TextField(
                  controller: controllerpassword,
                  obscureText: true,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color.fromARGB(255, 255, 251, 0),
                  ),
                  keyboardType: TextInputType.visiblePassword,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: login,
                      child: const Text('Login'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        register();
                        // The toast message here might be premature since registration is async.
                        // The message is shown inside the register() function on error.
                        // A success message should be shown after a successful registration.
                        // For now, I'll keep the original logic but this is a point for improvement.
                        Fluttertoast.showToast(
                          msg: 'Registration attempt sent.',
                          toastLength: Toast.LENGTH_SHORT,
                          gravity: ToastGravity.BOTTOM,
                        );
                      },
                      child: const Text('Register'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
