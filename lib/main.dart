import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'गौरादह शिक्षक हाजिरी',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: LoginScreen(),
    );
  }
}

// १. Gmail Login Screen (Mockup/Auth)
class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal.shade50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school, size: 80, color: Colors.teal),
              SizedBox(height: 20),
              Text('गौरादह नगरपालिका', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal.shade800)),
              Text('शिक्षक हाजिरी प्रणाली', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
              SizedBox(height: 40),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  elevation: 2,
                ),
                icon: Icon(Icons.g_mobiledata, size: 30, color: Colors.red),
                label: Text('Google (Gmail) मार्फत लगइन गर्नुहोस्', style: TextStyle(fontSize: 16)),
                onPressed: () {
                  // सफल Gmail लगइन पछि Attendance Scanner मा जाने
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => AttendanceScannerScreen(teacherEmail: "teacher@gmail.com", teacherId: "TCH001", schoolId: "040180018")),
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

// २. QR Scanner & Biometric Screen
class AttendanceScannerScreen extends StatefulWidget {
  final String teacherEmail;
  final String teacherId;
  final String schoolId;

  AttendanceScannerScreen({required this.teacherEmail, required this.teacherId, required this.schoolId});

  @override
  _AttendanceScannerScreenState createState() => _AttendanceScannerScreenState();
}

class _AttendanceScannerScreenState extends State<AttendanceScannerScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isProcessing = false;

  // बायोमेट्रिक प्रमाणीकरण (Fingerprint / Face ID) गर्ने फंक्शन
  Future<void> _authenticateAndMarkAttendance(String scannedData, String actionType) async {
    try {
      bool authenticated = await auth.authenticate(
        localizedReason: 'हाजिरी प्रमाणित गर्न कृपया आफ्नो फिंगरप्रिन्ट वा फेस आइडी दिनुहोस्',
        options: const AuthenticationOptions(
          stickyAuthentication: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        // बायोमेट्रिक पास भएपछि Google Apps Script API मा डेटा पठाउने
        await _sendDataToServer(actionType);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('बायोमेट्रिक प्रमाणीकरण असफल भयो!')),
        );
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('त्रुटि: $e')),
      );
    }
  }

  // गुगल सिटमा डाटा पठाउने API कल
  Future<void> _sendDataToServer(String actionType) async {
    // ⚠️ तलको URL को सट्टा आफ्नो Google Apps Script को वास्तविक Web App URL राख्नुहोला
    var url = Uri.parse("https://script.google.com/macros/s/AKfycbzDKJa7UEvol-1ZkAcggPZweVb622w9FatHZAnUjrARuMKCcF8nN57WA8ayVoZzUTt1/exec");

    try {
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "action": actionType, // "checkin" वा "checkout"
          "teacher_id": widget.teacherId,
          "teacher_name": "राम कुमार अधिकारी",
          "school_id": widget.schoolId,
        }),
      );

      var resData = jsonDecode(response.body);
      if (resData["status"] == "success") {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('सफल!'),
            content: Text(resData["message"]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text('ओके'))
            ],
          ),
        );
      }
    } catch (e) {
      print("API Error: $e");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('स्कुल QR स्क्यान गर्नुहोस्')),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: MobileScanner(
              onDetect: (capture) {
                if (_isProcessing) return;
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null && barcode.rawValue!.startsWith("GAURADAHA_ATTENDANCE")) {
                    setState(() => _isProcessing = true);
                    
                    // हाललाई चेक-इन (checkin) को रूपमा राखिएको छ
                    _authenticateAndMarkAttendance(barcode.rawValue!, "checkin");
                    break;
                  }
                }
              },
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: _isProcessing 
                ? CircularProgressIndicator()
                : Text('विद्यालयको स्क्रिनमा भएको QR स्क्यान गर्नुहोस्', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }
}