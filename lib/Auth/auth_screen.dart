import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'package:nhap/Home/home_page.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  bool _isRegistering = false;
  bool _isForgotPassword = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isRegistering = !_isRegistering;
      _isForgotPassword = false;
    });
  }

  void _toggleForgotPassword() {
    setState(() {
      _isForgotPassword = !_isForgotPassword;
      _isRegistering = false;
    });
  }

  Future<void> _submit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    bool success;

    if (_isForgotPassword) {
      success = await authService.resetPassword(
        context: context,
        email: _emailController.text.trim(),
      );
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent. Check your inbox.'),
            backgroundColor: Colors.teal,
          ),
        );
        setState(() {
          _isForgotPassword = false;
        });
      }
      return;
    }

    if (_isRegistering) {
      success = await authService.registerUser(
        context: context,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        phoneNumber: _phoneNumberController.text.trim(),
      );
    } else {
      success = await authService.signInUser(
        context: context,
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    }

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) =>  HomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isForgotPassword
                      ? 'Reset Password'
                      : _isRegistering
                      ? 'Register'
                      : 'Login',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _isForgotPassword
                      ? 'Enter your email to reset password'
                      : _isRegistering
                      ? 'Create your account'
                      : 'Welcome back',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),
                if (_isRegistering && !_isForgotPassword) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _firstNameController,
                          label: 'First Name',
                          validator: (value) =>
                          value!.isEmpty ? 'Enter first name' : null,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          controller: _lastNameController,
                          label: 'Last Name',
                          validator: (value) =>
                          value!.isEmpty ? 'Enter last name' : null,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  validator: (value) {
                    if (value!.isEmpty) return 'Enter email';
                    if (!AuthService.isValidEmail(value.trim())) return 'Invalid email format';
                    return null;
                  },
                ),
                if (!_isForgotPassword) ...[
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _passwordController,
                    label: 'Password',
                    obscureText: true,
                    validator: (value) =>
                    value!.isEmpty ? 'Enter password' : null,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(20),
                    ],
                  ),
                ],
                if (_isRegistering && !_isForgotPassword) ...[
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _phoneNumberController,
                    label: 'Phone Number',
                    validator: (value) =>
                    value!.isEmpty ? 'Enter phone number' : null,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                if (authService.errorMessage != null)
                  Center(
                    child: Text(
                      authService.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 80,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: authService.isLoading
                        ? null
                        : () => _submit(context),
                    child: Text(
                      _isForgotPassword
                          ? 'Send Reset Email'
                          : _isRegistering
                          ? 'Register'
                          : 'Login',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (!_isForgotPassword)
                  Center(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.teal),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: authService.isLoading
                          ? null
                          : () async {
                        bool success =
                        await authService.signInWithGoogle(context);
                        if (success) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>  HomePage(),
                            ),
                          );
                        }
                      },
                      icon: Image.network(
                        'https://www.google.com/favicon.ico',
                        height: 24,
                      ),
                      label: const Text(
                        'Sign in with Google',
                        style: TextStyle(fontSize: 16, color: Colors.teal),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!_isRegistering)
                        TextButton(
                          onPressed: _toggleForgotPassword,
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(color: Colors.teal, fontSize: 12),
                          ),
                        ),
                      if (!_isRegistering && !_isForgotPassword)
                        const Text(
                          '|',
                          style: TextStyle(color: Colors.teal, fontSize: 16),
                        ),
                      TextButton(
                        onPressed: _isForgotPassword ? _toggleMode : _toggleMode,
                        child: Text(
                          _isForgotPassword
                              ? 'Back to Login'
                              : _isRegistering
                              ? 'Already have an account? Login'
                              : 'Need an account? Register',
                          style: const TextStyle(color: Colors.teal, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          label.contains('Email')
              ? Icons.email
              : label.contains('Password')
              ? Icons.lock
              : label.contains('Phone')
              ? Icons.phone
              : Icons.person,
          color: Colors.teal,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: Colors.grey[200],
        contentPadding: const EdgeInsets.symmetric(
          vertical: 20,
          horizontal: 20,
        ),
      ),
      validator: validator,
      style: const TextStyle(fontSize: 16),
    );
  }
}