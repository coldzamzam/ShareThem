import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // State to toggle between initial buttons and email login form
  bool _showEmailLoginForm = false;

  // Controllers for text fields
  final TextEditingController _emailController = TextEditingController();

  // Global key for the form to enable validation
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // Handles the email login submission
  void _handleEmailLogin() {
    if (_formKey.currentState?.validate() ?? false) {
      // If the form is valid, print the credentials
      print('Email: ${_emailController.text}');
      // In a real app, you would integrate with an authentication service here.
      // For demonstration, we'll just show a snackbar.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logging in with ${_emailController.text}...'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive layout
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      resizeToAvoidBottomInset: false, // Prevent resize when keyboard appears
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF8E44AD), // Darker purple
                  Color(0xFFD2B4DE), // Lighter purple/pink
                ],
              ),
            ),
          ),
          // Content
          Column(
            children: [
              // Top spacing and "Sign in to ShareThem" text
              SizedBox(height: screenSize.height * 0.15),
              Text(
                'Sign in to ShareThem',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32, // Responsive font size
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Flexible space to push the card down
              const Spacer(),
              // White Login Card
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 500),
                  child: Card(
                    margin: EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        20.0,
                      ), // Rounded corners
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: AnimatedSwitcher(
                        duration: const Duration(
                          milliseconds: 100,
                        ), // Smooth transition
                        child:
                            _showEmailLoginForm
                                ? _buildEmailLoginForm(context)
                                : _buildInitialButtons(context),
                      ),
                    ),
                  ),
                ),
              ),
              // Flexible space to push copyright down
              const Spacer(),
              // Copyright Text
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Text(
                  '© ShareThem Copyright Kelompok 2 PBL 2025',
                  style: TextStyle(color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget for the initial Google and Email buttons
  Widget _buildInitialButtons(BuildContext context) {
    return Column(
      key: const ValueKey<int>(0), // Key for AnimatedSwitcher
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Sign In',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        // Google Sign In Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              // Handle Google Sign In
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Google Sign In functionality not implemented.',
                  ),
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                ),
              );
            },
            icon: Image.network(
              'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
              height: 20,
              errorBuilder:
                  (context, error, stackTrace) =>
                      const Icon(Icons.g_mobiledata), // Fallback icon
            ),
            label: const Text('Google'),
            style: ElevatedButton.styleFrom(
              foregroundColor:
                  Theme.of(context).colorScheme.onSurface, // Text color
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Email Sign In Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _showEmailLoginForm = true; // Show email login form
              });
            },
            icon: const Icon(Icons.email),
            label: const Text('Email'),
            style: ElevatedButton.styleFrom(
              foregroundColor:
                  Theme.of(context).colorScheme.onSurface, // Text color
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Email Sign In Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pushReplacementNamed(context, '/'),
            icon: const Icon(Icons.home),
            label: const Text('Back to home'),
            style: ElevatedButton.styleFrom(
              foregroundColor:
                  Theme.of(context).colorScheme.onSurface, // Text color
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Widget for the email login form
  Widget _buildEmailLoginForm(BuildContext context) {
    return Form(
      key: _formKey, // Assign the form key
      child: Column(
        key: const ValueKey<int>(1), // Key for AnimatedSwitcher
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Login with Email',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          // Email Input Field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'Enter your email',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              prefixIcon: const Icon(Icons.person),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          // Login Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleEmailLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Theme.of(
                      context,
                    ).colorScheme.primary, // Primary color for login button
                foregroundColor:
                    Theme.of(context).colorScheme.onPrimary, // Text color
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Send Code',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Login Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _showEmailLoginForm = false; // Go back to initial buttons
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Theme.of(
                      context,
                    ).colorScheme.secondary, // Primary color for login button
                foregroundColor:
                    Theme.of(context).colorScheme.onSecondary, // Text color
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Back',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
