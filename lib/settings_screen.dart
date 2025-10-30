import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:onepointapp/main.dart';

class SettingsScreen extends StatefulWidget {
  final Function(int) onSpeedChanged; // Callback for speed change

  const SettingsScreen({super.key, required this.onSpeedChanged});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int practiceSpeed = 50;
  bool isSoundOn = true;
  User? _currentUser;
  String? _uid;
  bool _isAnonymous = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadCurrentUser();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload settings when the screen is revisited
    _loadSettings();
  }

  Future<void> _loadCurrentUser() async {
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      setState(() {
        _uid = _currentUser!.uid;
        _isAnonymous = _currentUser!.isAnonymous;
      });
    }
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      practiceSpeed = prefs.getInt('practiceSpeed') ?? 50;
      isSoundOn = prefs.getBool('isSoundOn') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('practiceSpeed', practiceSpeed);
    await prefs.setBool('isSoundOn', isSoundOn);
    // Trigger callback to notify PracticeModeScreen of the change
    widget.onSpeedChanged(practiceSpeed);

    // Optionally: Pop the screen after saving
    Navigator.pop(context);
  }

  Future<void> _deleteAnonymousAccount() async {
    try {
      await _currentUser?.delete();
      // Clear local data after account deletion
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted successfully.')),
        );
        // Navigate back to the home screen and remove all previous routes
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => HomePage(changeLanguage: (_) {}),
          ),
          (Route<dynamic> route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting account: ${e.message}')),
        );
      }
    }
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account?'),
          content: const Text(
            'Are you sure you want to permanently delete your account? All your progress and data will be lost.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _deleteAnonymousAccount();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 30),
            const Text(
              'Practice Mode Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Speed (ms): '),
                Expanded(
                  child: Slider(
                    value: practiceSpeed.toDouble(),
                    min: 10,
                    max: 100,
                    divisions: 90,
                    label: practiceSpeed.round().toString(),
                    onChanged: (double value) {
                      setState(() {
                        practiceSpeed = value.round();
                      });
                    },
                  ),
                ),
                Text(practiceSpeed.toString()),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Sound: '),
                Switch(
                  value: isSoundOn,
                  onChanged: (value) {
                    setState(() {
                      isSoundOn = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(onPressed: _saveSettings, child: const Text('Save')),
            const Divider(height: 40),
            const Text(
              'Account Management',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_isAnonymous && _uid != null) ...[
              ListTile(
                title: const Text('Anonymous User ID'),
                subtitle: Text(
                  _uid!,
                  style: const TextStyle(color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _uid!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User ID copied!')),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: _showDeleteConfirmationDialog,
                  child: const Text('Delete Account'),
                ),
              ),
            ] else
              const Text('No anonymous account found.'),
          ],
        ),
      ),
    );
  }
}
