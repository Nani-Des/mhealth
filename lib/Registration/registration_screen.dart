// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/services.dart';
// import '../Components/EmailInputFormatter.dart';
// import '../Login/login_screen.dart';
// import '../Login/login_screen1.dart';
// import 'Components/registration_service.dart';
//
// class RegistrationScreen extends StatefulWidget {
//   @override
//   _RegistrationScreenState createState() => _RegistrationScreenState();
// }
//
// class _RegistrationScreenState extends State<RegistrationScreen> {
//   final TextEditingController _firstNameController = TextEditingController();
//   final TextEditingController _lastNameController = TextEditingController();
//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();
//   final TextEditingController _confirmPasswordController = TextEditingController();
//
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
//                     'Register',
//                     style: TextStyle(
//                       fontSize: 34.0,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.teal,
//                     ),
//                   ),
//                   const SizedBox(height: 3.0),
//                   Text(
//                     'Create your account',
//                     style: TextStyle(
//                       fontSize: 14.0,
//                       color: Colors.grey[600],
//                     ),
//                   ),
//                   const SizedBox(height: 20.0),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: _buildTextField(
//                           controller: _firstNameController,
//                           labelText: 'First Name',
//                           icon: Icons.person,
//                           obscureText: false,
//                           inputFormatters: [
//                             FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
//                           ],
//                         ),
//                       ),
//                       const SizedBox(width: 10.0),
//                       Expanded(
//                         child: _buildTextField(
//                           controller: _lastNameController,
//                           labelText: 'Last Name',
//                           icon: Icons.person,
//                           obscureText: false,
//                           inputFormatters: [
//                             FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 20.0),
//                   _buildTextField(
//                     controller: _emailController,
//                     labelText: 'Email',
//                     icon: Icons.email,
//                     obscureText: false,
//                     inputFormatters: [
//                       EmailInputFormatter(),
//                     ],
//                   ),
//                   const SizedBox(height: 20.0),
//                   _buildTextField(
//                     controller: _passwordController,
//                     labelText: 'Password',
//                     icon: Icons.lock,
//                     obscureText: true,
//                     inputFormatters: [
//                       LengthLimitingTextInputFormatter(20),
//                     ],
//                   ),
//                   const SizedBox(height: 20.0),
//                   _buildTextField(
//                     controller: _confirmPasswordController,
//                     labelText: 'Confirm Password',
//                     icon: Icons.lock,
//                     obscureText: true,
//                     inputFormatters: [
//                       LengthLimitingTextInputFormatter(20),
//                     ],
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
//                         if (_passwordController.text == _confirmPasswordController.text) {
//                           if (RegistrationService.isValidEmail(_emailController.text.trim())) {
//                             await _registerUser(context);
//                           } else {
//                             setState(() {
//                               _errorMessage = 'Invalid email address';
//                               _isLoading = false;
//                             });
//                           }
//                         } else {
//                           setState(() {
//                             _errorMessage = 'Passwords do not match';
//                             _isLoading = false;
//                           });
//                         }
//                       },
//                       child: const Text(
//                         'Continue',
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
//                           MaterialPageRoute(builder: (context) => LoginScreen1()),
//                         );
//                       },
//                       child: const Text(
//                         'Already have an account? Login',
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
//     List<TextInputFormatter>? inputFormatters,
//   }) {
//     return TextField(
//       controller: controller,
//       obscureText: obscureText,
//       inputFormatters: inputFormatters,
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
//   Future<void> _registerUser(BuildContext context) async {
//     try {
//       await RegistrationService.registerUser(
//         context,
//         _firstNameController.text.trim(),
//         _lastNameController.text.trim(),
//         _emailController.text.trim(),
//         _passwordController.text.trim(),
//       );
//       // Navigate to the next screen after successful registration
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (context) => LoginScreen1()), // Replace with your desired screen
//       );
//     } catch (e) {
//       setState(() {
//         _errorMessage = e.toString();
//       });
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
//
//   Future<void> _signInWithGoogle(BuildContext context) async {
//     try {
//       String? userId = await RegistrationService.signInWithGoogle(context);
//       if (userId != null) {
//         // Navigate to the next screen after successful Google Sign-In and PhoneNumberDialog
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (context) => LoginScreen1()), // Replace with your desired screen
//         );
//       }
//     } catch (e) {
//       setState(() {
//         _errorMessage = 'Google sign-in failed: ${e.toString()}';
//       });
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
// }