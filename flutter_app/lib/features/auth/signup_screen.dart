import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/exceptions.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_form.dart';
import 'auth_card.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .signUp(_emailController.text.trim(), _passwordController.text);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: AuthCard(
        title: 'Create your account',
        description: 'Create an account to start managing work with your team.',
        error: _error,
        children: [
          AppTextField(
            label: 'Email',
            controller: _emailController,
            hint: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Email is required' : null,
          ),
          AppTextField(
            label: 'Password',
            controller: _passwordController,
            hint: '••••••••',
            obscure: true,
            validator: (v) => (v == null || v.length < 6)
                ? 'Password must be at least 6 characters'
                : null,
          ),
          AppButton(
            'Create Account',
            expand: true,
            loading: _submitting,
            onPressed: _submit,
          ),
          AppButton.secondary(
            'Already have an account? Sign In',
            expand: true,
            onPressed: () => context.push('/login'),
          ),
        ],
      ),
    );
  }
}
