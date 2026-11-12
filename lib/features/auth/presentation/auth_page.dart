import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../application/auth_controller.dart';
import '../domain/auth_validators.dart';
import 'widgets/auth_layout.dart';
import 'widgets/password_field.dart';

enum AuthPageMode { login, register, reset }

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.controller, required this.mode});
  final AuthController controller;
  final AuthPageMode mode;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _resetSent = false;
  bool get _register => widget.mode == AuthPageMode.register;
  bool get _reset => widget.mode == AuthPageMode.reset;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _navigate(String path) {
    widget.controller.clearActionMessage();
    context.go(path);
  }

  Future<void> _submit() async {
    if (widget.controller.busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    if (_reset) {
      setState(() => _resetSent = false);
      final sent = await widget.controller.sendPasswordReset(
        _email.text.trim(),
      );
      if (mounted) setState(() => _resetSent = sent);
    } else if (_register) {
      await widget.controller.register(
        _name.text.trim(),
        _email.text.trim(),
        _password.text,
      );
    } else {
      await widget.controller.signIn(_email.text.trim(), _password.text);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final busy = widget.controller.busy;
      final title = _reset
          ? 'Lupa password?'
          : _register
          ? 'Mulai lebih tertata.'
          : 'Selamat datang kembali.';
      final subtitle = _reset
          ? 'Masukkan email Anda. Kami akan membantu Anda mengatur password baru.'
          : _register
          ? 'Buat akun Finova untuk mulai mengelola keuangan bisnis Anda.'
          : 'Masuk untuk melanjutkan perjalanan keuangan bisnis Anda.';
      return AuthLayout(
        title: title,
        subtitle: subtitle,
        footer: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              _register
                  ? 'Sudah memiliki akun?'
                  : _reset
                  ? 'Sudah ingat password?'
                  : 'Belum memiliki akun?',
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () =>
                        _navigate(_register || _reset ? '/login' : '/register'),
              child: Text(_register || _reset ? 'Masuk' : 'Daftar sekarang'),
            ),
          ],
        ),
        child: AutofillGroup(
          child: Form(
            key: _form,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.controller.actionMessage != null)
                  AuthMessage(message: widget.controller.actionMessage!),
                if (_resetSent)
                  const AuthMessage(
                    isError: false,
                    message:
                        'Jika email tersebut terdaftar, Anda akan menerima tautan reset password. '
                        'Periksa kotak masuk dan folder spam Anda.',
                  ),
                if (_register) ...[
                  TextFormField(
                    controller: _name,
                    enabled: !busy,
                    validator: AuthValidators.name,
                    autofillHints: const [AutofillHints.name],
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nama lengkap',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                TextFormField(
                  controller: _email,
                  enabled: !busy,
                  validator: AuthValidators.email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: _reset
                      ? TextInputAction.done
                      : TextInputAction.next,
                  onFieldSubmitted: _reset ? (_) => _submit() : null,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'nama@perusahaan.com',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                ),
                if (!_reset) ...[
                  const SizedBox(height: 18),
                  PasswordField(
                    controller: _password,
                    enabled: !busy,
                    label: 'Password',
                    isNewPassword: _register,
                    validator: _register
                        ? AuthValidators.registerPassword
                        : AuthValidators.loginPassword,
                    textInputAction: _register
                        ? TextInputAction.next
                        : TextInputAction.done,
                    onSubmitted: _register ? null : _submit,
                  ),
                  if (_register) ...[
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Minimal 8 karakter. Gunakan password yang unik.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 18),
                    PasswordField(
                      controller: _confirmation,
                      enabled: !busy,
                      label: 'Konfirmasi password',
                      isNewPassword: true,
                      validator: (value) =>
                          AuthValidators.confirmPassword(value, _password.text),
                      onSubmitted: _submit,
                    ),
                  ] else
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: busy
                            ? null
                            : () => _navigate('/forgot-password'),
                        child: const Text('Lupa password?'),
                      ),
                    ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: busy ? null : _submit,
                  child: busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            semanticsLabel: 'Memproses permintaan',
                          ),
                        )
                      : Text(
                          _reset
                              ? 'Kirim tautan reset'
                              : _register
                              ? 'Buat akun'
                              : 'Masuk',
                        ),
                ),
                if (!_reset) ...[
                  const SizedBox(height: 24),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('atau', style: TextStyle(fontSize: 12)),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            FocusScope.of(context).unfocus();
                            await widget.controller.signInWithGoogle();
                          },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Continue with Google'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
