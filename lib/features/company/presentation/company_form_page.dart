import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../auth/domain/auth_validators.dart';
import '../../auth/presentation/widgets/auth_layout.dart';
import '../application/company_controller.dart';
import '../domain/company.dart';
import 'svg_logo_picker.dart';

class CompanyFormPage extends StatefulWidget {
  const CompanyFormPage({super.key, required this.controller});
  final CompanyController controller;
  @override
  State<CompanyFormPage> createState() => _CompanyFormPageState();
}

class _CompanyFormPageState extends State<CompanyFormPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  String? _businessType;
  DateTime? _date;
  String? _logoSvg;
  String? _logoError;

  @override
  void dispose() {
    for (final field in [_name, _address, _phone, _email]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Tanggal mulai pembukuan',
    );
    if (mounted && value != null) setState(() => _date = value);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await widget.controller.createCompany(
      CompanyDraft(
        name: _name.text,
        businessType: _businessType!,
        bookkeepingStartDate: _date!,
        address: _address.text,
        phoneNumber: _phone.text,
        email: _email.text,
        logoSvg: _logoSvg,
      ),
    );
  }

  Future<void> _pickLogo() async {
    final result = await pickSvgLogo();
    if (!mounted || (result.svg == null && result.error == null)) return;
    setState(() {
      _logoSvg = result.svg ?? _logoSvg;
      _logoError = result.error;
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final busy = widget.controller.busy;
      return AuthLayout(
        title: 'Buat perusahaan.',
        subtitle: 'Siapkan identitas bisnis dan awal pembukuan. Anda menjadi Manager pertama perusahaan ini.',
        footer: TextButton(
          onPressed: busy ? null : () => context.go('/company'),
          child: const Text('Kembali ke pilihan perusahaan'),
        ),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.controller.message != null)
                AuthMessage(message: widget.controller.message!),
              TextFormField(
                controller: _name,
                enabled: !busy,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama perusahaan *',
                ),
                validator: CompanyValidators.name,
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: _businessType,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Jenis usaha *'),
                items: CompanyValidators.businessTypes
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: busy
                    ? null
                    : (value) => setState(() => _businessType = value),
                validator: (value) =>
                    value == null ? 'Pilih jenis usaha.' : null,
              ),
              const SizedBox(height: 18),
              FormField<DateTime>(
                validator: (_) => CompanyValidators.date(_date),
                builder: (field) => InkWell(
                  onTap: busy ? null : _pickDate,
                  borderRadius: BorderRadius.circular(16),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Tanggal mulai pembukuan *',
                      errorText: field.errorText,
                      suffixIcon: const Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(
                      _date == null
                          ? 'Pilih tanggal'
                          : '${_date!.day.toString().padLeft(2, '0')}/${_date!.month.toString().padLeft(2, '0')}/${_date!.year}',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Mata uang: Rupiah (IDR)',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 28),
              Text(
                'Informasi tambahan',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _address,
                enabled: !busy,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Alamat (opsional)',
                ),
                validator: CompanyValidators.address,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _phone,
                enabled: !busy,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telepon (opsional)',
                ),
                validator: AuthValidators.phone,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _email,
                enabled: !busy,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email perusahaan (opsional)',
                ),
                validator: CompanyValidators.email,
              ),
              const SizedBox(height: 28),
              Text(
                'Logo perusahaan',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Unggah file SVG (maks. 50 KB). Logo opsional; ikon bisnis digunakan jika kosong.',
                style: TextStyle(
                  color: AppColors.muted,
                  height: 1.6,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              Center(child: CompanyLogo(svg: _logoSvg, size: 80)),
              const SizedBox(height: 12),
              if (_logoError != null) AuthMessage(message: _logoError!),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: busy ? null : _pickLogo,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(
                      _logoSvg == null ? 'Unggah logo SVG' : 'Ganti logo SVG',
                    ),
                  ),
                  if (_logoSvg != null)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              _logoSvg = null;
                              _logoError = null;
                            }),
                      child: const Text('Hapus logo'),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: busy ? null : _submit,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_business_rounded),
                label: Text(busy ? 'Menyimpan perusahaan…' : 'Buat perusahaan'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(18),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class CompanyLogo extends StatelessWidget {
  const CompanyLogo({super.key, this.svg, this.size = 40});

  /// Teks SVG yang sudah divalidasi; ditampilkan hanya lewat flutter_svg.
  final String? svg;
  final double size;
  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: AppColors.surface,
      child: Center(
        child: Icon(
          Icons.business_rounded,
          color: AppColors.primary,
          size: size * .5,
        ),
      ),
    );
    return Semantics(
      label: 'Logo perusahaan',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: size,
          height: size,
          child: svg == null
              ? fallback
              : SvgPicture.string(
                  svg!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stack) => fallback,
                ),
        ),
      ),
    );
  }
}
