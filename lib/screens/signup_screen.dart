import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/pattern_background.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // 0:이메일, 1:인증, 2:비밀번호, 3:키생성(New), 4:완료
  int _step = 0;
  bool _isBusy = false;
  String _loadingMessage = ""; // 로딩 상태 메시지

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------
  // 로직 처리 함수들
  // --------------------------------------------------------------

  // [Step 0 -> 1] 인증번호 요청
  Future<void> _requestCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnackBar('올바른 이메일을 입력해주세요.');
      return;
    }

    setState(() {
      _isBusy = true;
      _loadingMessage = "서버와 통신 중...";
    });

    final provider = context.read<AppProvider>();
    final success = await provider.requestVerificationCode(email);

    if (!mounted) return;
    setState(() => _isBusy = false);

    if (success) {
      setState(() => _step = 1);
      _showSnackBar('인증번호가 발송되었습니다.');
    } else {
      _showSnackBar(provider.registrationErrorMessage ?? '요청 실패');
    }
  }

  // [Step 1 -> 2] 인증번호 검증
  Future<void> _checkCode() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();

    if (code.length < 6) {
      _showSnackBar('6자리 인증번호를 입력해주세요.');
      return;
    }

    setState(() {
      _isBusy = true;
      _loadingMessage = "인증번호 확인 중...";
    });

    final provider = context.read<AppProvider>();
    final success = await provider.submitVerificationCode(email, code);

    if (!mounted) return;
    setState(() => _isBusy = false);

    if (success) {
      setState(() => _step = 2); // 비밀번호 설정 단계로
    } else {
      _showSnackBar(provider.registrationErrorMessage ?? '인증 실패');
    }
  }

  // [Step 2 -> 3] 비밀번호 유효성 검사 (아직 서버 전송 안 함)
  void _validatePasswordAndNext() {
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (password.length < 4) {
      _showSnackBar('비밀번호는 4자 이상이어야 합니다.');
      return;
    }
    if (password != confirm) {
      _showSnackBar('비밀번호가 일치하지 않습니다.');
      return;
    }

    // 비밀번호가 정상이면 키 생성 단계로 이동
    setState(() => _step = 3);
  }

  // [Step 3 -> 4] 키 생성 및 업로드 (최종 가입)
  Future<void> _startKeyGenerationAndUpload() async {
    setState(() {
      _isBusy = true;
      _loadingMessage = "동형암호 키 생성 중...\n(PC 성능에 따라 시간이 소요될 수 있습니다)";
    });

    final provider = context.read<AppProvider>();

    // 1. 키 생성 및 암호화 (C++ 연산)
    // 2. 회원가입 요청
    // 3. 로그인 및 키 업로드
    // 이 모든 과정이 provider.finalizeRegistration 안에 있음
    final success = await provider.finalizeRegistration(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _isBusy = false;
        _step = 4; // 완료 화면으로
      });
    } else {
      setState(() => _isBusy = false);
      _showSnackBar(provider.registrationErrorMessage ?? '작업 실패');
    }
  }

  void _handlePrimaryAction() {
    switch (_step) {
      case 0:
        _requestCode();
        break;
      case 1:
        _checkCode();
        break;
      case 2:
        _validatePasswordAndNext(); // 바로 가입 요청 X, 다음 단계로
        break;
      case 3:
        _startKeyGenerationAndUpload(); // 여기서 실제 무거운 작업 수행
        break;
      case 4:
        Navigator.of(context).pop(_emailController.text.trim());
        break;
    }
  }

  void _goBack() {
    if (_step == 0) {
      Navigator.of(context).pop();
    } else {
      setState(() => _step -= 1);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // --------------------------------------------------------------
  // UI 위젯들
  // --------------------------------------------------------------

  Widget _buildStepBody() {
    switch (_step) {
      case 0:
        return _buildEmailStep();
      case 1:
        return _buildCodeStep();
      case 2:
        return _buildPasswordStep();
      case 3:
        return _buildKeyGenStep(); // [NEW] 키 생성 화면
      case 4:
        return _buildDoneStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('로그인에 사용할 이메일을 입력하세요.'),
        const SizedBox(height: 12),
        _decoratedField(
          controller: _emailController,
          label: 'Email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
      ],
    );
  }

  Widget _buildCodeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('서버 로그(또는 메일)로 받은 6자리 인증번호를 입력하세요.'),
        const SizedBox(height: 12),
        _decoratedField(
          controller: _codeController,
          label: '인증번호',
          icon: Icons.verified_outlined,
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('계정 비밀번호를 설정하세요.'),
        const SizedBox(height: 12),
        _decoratedField(
          controller: _passwordController,
          label: '비밀번호',
          icon: Icons.lock_outline,
          obscure: true,
        ),
        const SizedBox(height: 12),
        _decoratedField(
          controller: _confirmPasswordController,
          label: '비밀번호 확인',
          icon: Icons.lock_reset_outlined,
          obscure: true,
        ),
      ],
    );
  }

  // [NEW] 키 생성 및 업로드 단계 UI
  Widget _buildKeyGenStep() {
    if (_isBusy) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            const CircularProgressIndicator(strokeWidth: 3),
            const SizedBox(height: 24),
            Text(
              _loadingMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              "앱을 종료하지 마세요.",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '보안 키 생성 준비 완료',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.accentBlue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.accentBlue.withOpacity(0.2)),
          ),
          child: Column(
            children: const [
              Row(
                children: [
                  Icon(Icons.vpn_key, color: AppTheme.accentBlue, size: 20),
                  SizedBox(width: 12),
                  Text("동형암호 키 (Relin, Galois) 생성"),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.cloud_upload,
                    color: AppTheme.accentBlue,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Text("서버로 안전하게 업로드"),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '아래 버튼을 누르면 키 생성이 시작됩니다.\n이 과정은 몇 초 정도 걸릴 수 있습니다.',
          style: TextStyle(color: AppTheme.muted, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildDoneStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.check_circle, color: Colors.green, size: 64),
        SizedBox(height: 24),
        Text(
          '회원가입 완료!',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        SizedBox(height: 12),
        Text(
          '모든 보안 설정이 끝났습니다.\n이제 로그인 화면으로 이동해 서비스를 이용하세요.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.muted),
        ),
      ],
    );
  }

  Widget _decoratedField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.accentBlueDark),
        filled: true,
        fillColor: AppTheme.accentBlue.withOpacity(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  String get _primaryButtonLabel {
    switch (_step) {
      case 0:
        return '인증번호 받기';
      case 1:
        return '인증번호 확인';
      case 2:
        return '다음 (키 생성)';
      case 3:
        return '키 생성 및 회원가입 완료';
      case 4:
        return '로그인 화면으로';
      default:
        return '다음';
    }
  }

  @override
  Widget build(BuildContext context) {
    // 로딩 중일 때는 버튼을 숨기거나 비활성화하기 위해
    final bool hideButtons = (_step == 3 && _isBusy) || (_step == 4);

    return Scaffold(
      appBar: AppBar(
        title: const Text('회원가입'),
        automaticallyImplyLeading: !_isBusy, // 로딩 중 뒤로가기 방지
      ),
      body: PatternBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 상단 인디케이터
                      StepProgressIndicator(currentStep: _step),
                      const SizedBox(height: 24),

                      // 메인 컨텐츠 (Expanded로 남은 공간 채움)
                      Expanded(
                        child: SingleChildScrollView(child: _buildStepBody()),
                      ),

                      const SizedBox(height: 24),

                      // 하단 버튼 영역
                      if (!hideButtons)
                        Row(
                          children: [
                            if (_step > 0)
                              TextButton(
                                onPressed: _isBusy ? null : _goBack,
                                child: const Text('이전'),
                              ),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: _isBusy ? null : _handlePrimaryAction,
                              child: _isBusy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(_primaryButtonLabel),
                            ),
                          ],
                        ),
                      // 완료 화면일 때의 버튼
                      if (_step == 4)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(
                              context,
                            ).pop(_emailController.text.trim()),
                            child: const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Text("로그인하러 가기"),
                            ),
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
    );
  }
}

// 단계 표시기 위젯
class StepProgressIndicator extends StatelessWidget {
  final int currentStep;
  const StepProgressIndicator({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final steps = ['이메일', '인증', '비밀번호', '키 생성', '완료'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(steps.length, (index) {
        final isActive = index <= currentStep;
        return Expanded(
          child: Column(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: isActive
                    ? AppTheme.accentBlue
                    : Colors.grey.shade300,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                steps[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isActive ? Colors.black87 : Colors.grey,
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
