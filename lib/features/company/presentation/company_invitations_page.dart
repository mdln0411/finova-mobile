import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/finova_card.dart';
import '../../auth/domain/auth_validators.dart';
import '../../auth/presentation/widgets/auth_layout.dart';
import '../application/company_controller.dart';

class CompanyInvitationsPage extends StatefulWidget {
  const CompanyInvitationsPage({
    super.key,
    required this.controller,
    this.manage = false,
  });
  final CompanyController controller;
  final bool manage;
  @override
  State<CompanyInvitationsPage> createState() => _CompanyInvitationsPageState();
}

class _CompanyInvitationsPageState extends State<CompanyInvitationsPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  String? _notice;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.loadInvitations();
    });
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final busy = controller.busy;
      return AuthLayout(
        title: widget.manage ? 'Undang tim Finance.' : 'Undangan perusahaan.',
        subtitle: widget.manage
            ? 'Undang email anggota. Peran undangan selalu Finance; akun penerima harus memverifikasi email.'
            : 'Undangan untuk ${controller.auth.user?.email ?? "akun Anda"}. '
                  'Terima undangan Manager untuk masuk ke perusahaan sebagai Finance.',
        footer: TextButton(
          onPressed: busy
              ? null
              : () => context.go(widget.manage ? '/settings' : '/company'),
          child: Text(
            widget.manage
                ? 'Kembali ke Pengaturan'
                : 'Kembali ke pilihan perusahaan',
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (controller.message != null)
              AuthMessage(message: controller.message!),
            if (_notice != null) AuthMessage(message: _notice!, isError: false),
            if (widget.manage)
              Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _email,
                      enabled: !busy,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email Finance',
                      ),
                      validator: AuthValidators.email,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () async {
                              if (!_form.currentState!.validate()) return;
                              final success = await controller.inviteFinance(
                                _email.text,
                              );
                              if (mounted && success) {
                                _email.clear();
                                setState(
                                  () => _notice = 'Undangan tersedia di aplikasi penerima. Tidak ada email undangan otomatis.',
                                );
                              }
                            },
                      child: const Text('Buat undangan Finance'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              )
            else if (!controller.emailVerified && !busy) ...[
              const AuthMessage(
                isError: false,
                message:
                    'Verifikasi email diperlukan untuk membaca dan menerima undangan. '
                    'Setelah membuka tautan verifikasi, tekan Muat ulang undangan.',
              ),
              OutlinedButton(
                onPressed: () async {
                  if (await controller.sendVerificationEmail() && mounted) {
                    setState(
                      () => _notice =
                          'Tautan verifikasi dikirim. Periksa inbox atau spam.',
                    );
                  }
                },
                child: const Text('Kirim verifikasi email'),
              ),
            ],
            OutlinedButton.icon(
              onPressed: busy ? null : controller.loadInvitations,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Muat ulang undangan'),
            ),
            const SizedBox(height: 20),
            if (busy)
              const Center(child: CircularProgressIndicator())
            else if (controller.pendingInvitations.isEmpty)
              const FinovaCard(
                child: Text(
                  'Belum ada undangan pending. Hubungi Manager perusahaan jika Anda menunggu undangan.',
                ),
              ),
            for (final invitation in controller.pendingInvitations) ...[
              FinovaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      invitation.companyName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('${invitation.email}\nFinance · Menunggu penerimaan'),
                    const SizedBox(height: 16),
                    if (widget.manage)
                      OutlinedButton(
                        onPressed: busy
                            ? null
                            : () => controller.cancelInvitation(invitation.id),
                        child: const Text('Batalkan undangan'),
                      )
                    else ...[
                      FilledButton(
                        onPressed: busy
                            ? null
                            : () => controller.respond(
                                invitation.id,
                                accept: true,
                              ),
                        child: const Text('Terima dan gabung'),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => controller.respond(
                                invitation.id,
                                accept: false,
                              ),
                        child: const Text('Tolak undangan'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      );
    },
  );
}
