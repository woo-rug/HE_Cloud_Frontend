import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/pattern_background.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController(
    text: 'test@test.com',
  );
  final TextEditingController _passwordController = TextEditingController(
    text: '1234',
  );
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    final provider = context.read<AppProvider>();
    final success = await provider.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? '로그인에 실패했습니다.')),
      );
    }
  }

  Future<void> _goToSignUp() async {
    final email = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const SignUpScreen()));
    if (email != null) {
      _emailController.text = email;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('회원가입이 완료되었습니다. 로그인해주세요.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PatternBackground(
        child: Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: AppTheme.accentBlue.withOpacity(
                                0.12,
                              ),
                              child: const Icon(
                                Icons.cloud,
                                color: AppTheme.accentBlue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'HE Cloud',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: AppTheme.accentBlueDark,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Demo 계정  id: admin  /  password: 1234',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 24),
                        _buildTextField(
                          controller: _emailController,
                          label: '이메일 또는 아이디',
                          icon: Icons.person,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _passwordController,
                          label: '비밀번호',
                          icon: Icons.lock,
                          obscure: true,
                        ),
                        const SizedBox(height: 24),
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton(
                                onPressed: _login,
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  child: Text('로그인'),
                                ),
                              ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _isLoading ? null : _goToSignUp,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.accentBlueDark,
                            side: BorderSide(
                              color: AppTheme.accentBlue.withOpacity(0.25),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('아직 계정이 없나요? 회원가입'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.accentBlueDark),
        filled: true,
        fillColor: AppTheme.accentBlue.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
