// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import '../Registration/registration_screen.dart';
// import '../Registration/Components/registration_service.dart'; // Import RegistrationService
//
// class LoginScreen1 extends StatefulWidget {
//   @override
//   _LoginScreen1State createState() => _LoginScreen1State();
// }
//
// class _LoginScreen1State extends State<LoginScreen1> {
//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   String _errorMessage = '';
//   bool _isLoading = false;
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: Stack(
//         children: [
//           SingleChildScrollView(
//             child: Padding(
//               padding: const EdgeInsets.all(20.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const SizedBox(height: 50.0),
//                   const Text(
//                     'Login',
//                     style: TextStyle(
//                       fontSize: 34.0,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.teal,
//                     ),
//                   ),
//                   const SizedBox(height: 3.0),
//                   Text(
//                     'Sign in to your account',
//                     style: TextStyle(
//                       fontSize: 14.0,
//                       color: Colors.grey[600],
//                     ),
//                   ),
//                   const SizedBox(height: 20.0),
//                   _buildTextField(
//                     controller: _emailController,
//                     labelText: 'Email',
//                     icon: Icons.email,
//                     obscureText: false,
//                   ),
//                   const SizedBox(height: 20.0),
//                   _buildTextField(
//                     controller: _passwordController,
//                     labelText: 'Password',
//                     icon: Icons.lock,
//                     obscureText: true,
//                   ),
//                   const SizedBox(height: 10.0),
//                   if (_errorMessage.isNotEmpty)
//                     Center(
//                       child: Text(
//                         _errorMessage,
//                         style: const TextStyle(color: Colors.red),
//                       ),
//                     ),
//                   const SizedBox(height: 20.0),
//                   Center(
//                     child: ElevatedButton(
//                       style: ElevatedButton.styleFrom(
//                         padding: const EdgeInsets.symmetric(horizontal: 80.0, vertical: 15.0),
//                         backgroundColor: Colors.teal,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(30.0),
//                         ),
//                       ),
//                       onPressed: () async {
//                         setState(() {
//                           _errorMessage = '';
//                           _isLoading = true;
//                         });
//                         await _signInUser(context);
//                       },
//                       child: const Text(
//                         'Login',
//                         style: TextStyle(
//                           fontSize: 18.0,
//                           color: Colors.white,
//                         ),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 20.0),
//                   Center(
//                     child: OutlinedButton.icon(
//                       style: OutlinedButton.styleFrom(
//                         padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 15.0),
//                         side: const BorderSide(color: Colors.teal),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(30.0),
//                         ),
//                       ),
//                       onPressed: () async {
//                         setState(() {
//                           _errorMessage = '';
//                           _isLoading = true;
//                         });
//                         await _signInWithGoogle(context);
//                       },
//                       icon: Image.network(
//                         'https://www.google.com/favicon.ico',
//                         height: 24.0,
//                       ),
//                       label: const Text(
//                         'Sign in with Google',
//                         style: TextStyle(
//                           fontSize: 16.0,
//                           color: Colors.teal,
//                         ),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 20.0),
//                   Center(
//                     child: TextButton(
//                       onPressed: () {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(builder: (context) => RegistrationScreen()),
//                         );
//                       },
//                       child: const Text(
//                         'Don\'t have an account? Register',
//                         style: TextStyle(
//                           color: Colors.teal,
//                           fontSize: 16.0,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           if (_isLoading)
//             const Center(
//               child: CircularProgressIndicator(),
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildTextField({
//     required TextEditingController controller,
//     required String labelText,
//     required IconData icon,
//     required bool obscureText,
//   }) {
//     return TextField(
//       controller: controller,
//       obscureText: obscureText,
//       decoration: InputDecoration(
//         labelText: labelText,
//         prefixIcon: Icon(icon, color: Colors.teal),
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(10.0),
//         ),
//         filled: true,
//         fillColor: Colors.grey[200],
//         contentPadding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
//       ),
//       style: const TextStyle(
//         fontSize: 16.0,
//       ),
//     );
//   }
//
//   Future<void> _signInUser(BuildContext context) async {
//     try {
//       UserCredential userCredential = await _auth.signInWithEmailAndPassword(
//         email: _emailController.text.trim(),
//         password: _passwordController.text.trim(),
//       );
//
//       User? user = userCredential.user;
//       if (user != null) {
//         print('User signed in successfully with User ID: ${user.uid}');
//         Navigator.pop(context, user.uid); // Return the user ID to the previous screen
//       }
//     } catch (e) {
//       print('Error signing in: $e');
//       setState(() {
//         _errorMessage = 'Failed to sign in. Please check your email and password.';
//         _isLoading = false;
//       });
//     }
//   }
//
//   Future<void> _signInWithGoogle(BuildContext context) async {
//     try {
//       String? userId = await RegistrationService.signInWithGoogle(context);
//       if (userId != null) {
//         print('Google Sign-In successful with User ID: $userId');
//         Navigator.pop(context, userId); // Return the user ID to the previous screen
//       }
//     } catch (e) {
//       print('Error during Google Sign-In: $e');
//       setState(() {
//         _errorMessage = 'Google Sign-In failed: ${e.toString()}';
//         _isLoading = false;
//       });
//     }
//   }
// }