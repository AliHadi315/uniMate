import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _uniNameCtrl = TextEditingController();
  final _uniIdCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _uniNameCtrl.dispose();
    _uniIdCtrl.dispose();
    _passwordCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    final err = auth.signUp(
      fullName: _fullNameCtrl.text,
      universityName: _uniNameCtrl.text,
      universityId: _uniIdCtrl.text,
      password: _passwordCtrl.text,
      country: _countryCtrl.text,
    );

    setState(() => _loading = false);

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _fullNameCtrl,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter full name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _uniNameCtrl,
                decoration: const InputDecoration(labelText: 'University name'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Enter university name'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _uniIdCtrl,
                decoration: const InputDecoration(labelText: 'University ID'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Enter university id'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _countryCtrl,
                decoration: const InputDecoration(labelText: 'Country'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter country' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Enter password' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Create account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
