import 'dart:convert';

import '../../auth/domain/auth_validators.dart';

enum CompanyRole {
  manager('Manager'),
  finance('Finance');

  const CompanyRole(this.label);
  final String label;
}

class Company {
  const Company({
    required this.id,
    required this.name,
    required this.businessType,
    required this.bookkeepingStartDate,
    required this.createdBy,
    this.logoSvg,
  });
  final String id;
  final String name;
  final String businessType;
  final DateTime bookkeepingStartDate;
  final String createdBy;

  /// Isi teks SVG logo; null berarti memakai ikon bawaan.
  final String? logoSvg;
}

class CompanyContext {
  const CompanyContext({required this.company, required this.role});
  final Company company;
  final CompanyRole role;
}

class CompanyDraft {
  const CompanyDraft({
    required this.name,
    required this.businessType,
    required this.bookkeepingStartDate,
    this.address = '',
    this.phoneNumber = '',
    this.email = '',
    this.logoSvg,
  });
  final String name;
  final String businessType;
  final DateTime bookkeepingStartDate;
  final String address;
  final String phoneNumber;
  final String email;
  final String? logoSvg;

  String? validate() =>
      CompanyValidators.name(name) ??
      (CompanyValidators.businessTypes.contains(businessType)
          ? null
          : 'Pilih jenis usaha.') ??
      CompanyValidators.date(bookkeepingStartDate) ??
      CompanyValidators.address(address) ??
      AuthValidators.phone(phoneNumber) ??
      CompanyValidators.email(email) ??
      CompanyValidators.logoSvg(logoSvg);
}

abstract final class CompanyValidators {
  static const businessTypes = ['Dagang', 'Jasa', 'Manufaktur', 'Lainnya'];
  static String? name(String? value) {
    final name = value?.trim() ?? '';
    if (name.length < 2) return 'Nama perusahaan minimal 2 karakter.';
    if (name.length > 100) return 'Nama perusahaan maksimal 100 karakter.';
    return null;
  }

  static String? date(DateTime? value) =>
      value == null || value.year < 1900 || value.year > 2100
      ? 'Pilih tanggal pembukuan antara tahun 1900–2100.'
      : null;
  static String? address(String? value) => (value?.trim().length ?? 0) > 500
      ? 'Alamat maksimal 500 karakter.'
      : null;
  static String? email(String? value) => value == null || value.trim().isEmpty
      ? null
      : AuthValidators.email(value);

  /// Batas sama dengan Firestore Rules (`validLogoSvg`).
  static const maxLogoBytes = 50 * 1024;
  static final _eventAttribute = RegExp(r'[\s/]on[a-z]+\s*=');

  /// Validasi client hanya untuk UX; Rules tetap menjadi pengaman utama.
  static String? logoSvg(String? value) {
    if (value == null) return null;
    if (value.trim().isEmpty) return 'File SVG kosong.';
    if (utf8.encode(value).length > maxLogoBytes) {
      return 'Ukuran logo maksimal 50 KB.';
    }
    final lower = value.toLowerCase();
    if (!lower.contains('<svg')) return 'File bukan gambar SVG yang valid.';
    if (lower.contains('<script') || _eventAttribute.hasMatch(lower)) {
      return 'SVG tidak boleh berisi script atau atribut event (on…).';
    }
    return null;
  }
}

class CompanyInvitation {
  const CompanyInvitation({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.email,
    required this.status,
  });
  final String id;
  final String companyId;
  final String companyName;
  final String email;
  final String status;
}

class CompanyFailure implements Exception {
  const CompanyFailure(this.message);
  final String message;
}
