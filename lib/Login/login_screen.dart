import 'package:flutter/material.dart';
import 'package:mhealth/Registration/registration_screen.dart';

class LoginScreen extends StatelessWidget {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 50.0),
              const Text(
                'Login',
                style: TextStyle(
                  fontSize: 34.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 10.0),
              Text(
                'Sign in to your account',
                style: TextStyle(
                  fontSize: 18.0,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 30.0),
              _buildTextField(
                controller: _emailController,
                labelText: 'Email',
                icon: Icons.email,
                obscureText: false,
              ),
              const SizedBox(height: 20.0),
              _buildTextField(
                controller: _passwordController,
                labelText: 'Password',
                icon: Icons.lock,
                obscureText: true,
              ),
              const SizedBox(height: 30.0),
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 80.0, vertical: 15.0), backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                  ),
                  onPressed: () {
                    // Handle login logic here
                  },
                  child: const Text(
                    'Login',
                    style: TextStyle(
                      fontSize: 18.0,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20.0),
              Center(
                child: TextButton(
                  onPressed: () {
                    // Handle navigation to registration page
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => RegistrationScreen()),
                    );
                  },
                  child: const Text(
                    'Don\'t have an account? Register',
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 16.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String labelText, required IconData icon, required bool obscureText}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        filled: true,
        fillColor: Colors.grey[200],
        contentPadding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
      ),
      style: const TextStyle(
        fontSize: 16.0,
      ),
    );
  }
}