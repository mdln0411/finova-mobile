import 'package:flutter/material.dart';

import '../application/auth_controller.dart';
import '../domain/auth_validators.dart';
import 'widgets/auth_layout.dart';

class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key, required this.controller});
  final AuthController controller;
  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.controller.profile?.displayName ?? '',
  );
  late final _phone = TextEditingController(
    text: widget.controller.profile?.phoneNumber ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (widget.controller.busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await widget.controller.completeProfile(_name.text, _phone.text);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final auth = widget.controller;
      final photo = auth.user?.photoUrl ?? auth.profile?.photoUrl;
      final safePhoto = photo != null && Uri.tryParse(photo)?.scheme == 'https'
          ? photo
          : null;
      const fallback = Icon(Icons.person_outline_rounded, size: 42);
      return AuthLayout(
        title: 'Lengkapi profil Anda.',
        subtitle: 'Periksa informasi akun Anda sebelum melanjutkan ke ruang kerja Finova.',
        footer: TextButton(
          onPressed: auth.busy ? null : auth.signOut,
          child: const Text('Keluar dari akun'),
        ),
        child: AutofillGroup(
          child: Form(
            key: _form,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Semantics(
                    label: 'Foto profil',
                    image: true,
                    child: ClipOval(
                      child: SizedBox(
                        width: 88,
                        height: 88,
                        child: ColoredBox(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: safePhoto == null
                              ? fallback
                              : Image.network(
                                  safePhoto,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stack) =>
                                      fallback,
                                  loadingBuilder: (context, child, progress) =>
                                      progress == null
                                      ? child
                                      : const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Foto akun Google ditampilkan jika tersedia.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 24),
                if (auth.actionMessage != null)
                  AuthMessage(message: auth.actionMessage!),
                TextFormField(
                  controller: _name,
                  enabled: !auth.busy,
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
                TextFormField(
                  initialValue: auth.user?.email ?? '',
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    helperText:
                        'Email mengikuti akun yang digunakan untuk masuk.',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _phone,
                  enabled: !auth.busy,
                  validator: AuthValidators.phone,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  decoration: const InputDecoration(
                    labelText: 'Nomor telepon (opsional)',
                    hintText: '+62 812 3456 7890',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: auth.busy ? null : _save,
                  child: auth.busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            semanticsLabel: 'Menyimpan profil',
                          ),
                        )
                      : const Text('Simpan dan lanjutkan'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
