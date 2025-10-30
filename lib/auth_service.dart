import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

ValueNotifier<AuthService> authService = ValueNotifier<AuthService>(
  AuthService(),
);

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<User?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print('Error signing in: $e');
      return e is FirebaseAuthException
          ? null
          : throw Exception('Failed to sign in');
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      return userCredential;
    } catch (e) {
      print('Error registering: $e');
      throw Exception('Failed to register: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      print('Password reset email sent to $email');
    } catch (e) {
      print('Error sending password reset email: $e');
    }
  }

  getcurrentUser() {
    return _auth.currentUser;
  }

  Future<UserCredential> signInwithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } catch (e) {
      print('Error signing in with email and password: $e');
      throw e; // Re-throw the error for further handling
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      // 1. Trigger the Google Sign-In flow
      final GoogleSignInAccount? gUser = await GoogleSignIn.instance
          .authenticate();

      if (gUser == null) {
        // User cancelled the sign-in
        return null;
      }

      // 2. Obtain the auth details from the request
      final GoogleSignInAuthentication gAuth = await gUser.authentication;

      // 3. Create a new credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: gAuth.hashCode.toString(),
        idToken: gAuth.idToken,
      );

      // 4. Sign in to Firebase with the credential
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      // 5. Return the authenticated user
      return userCredential.user;
    } catch (e) {
      print('Error signing in with Google: $e');
      return null;
    }
  }

  Future<void> deleteAccount() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await user.delete();
        print('Account deleted successfully.');
      } else {
        print('No user found to delete.');
      }
    } catch (e) {
      print('Error deleting account: $e');
    }
  }

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}
