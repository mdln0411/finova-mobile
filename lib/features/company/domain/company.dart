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
    this.logoUrl,
  });
  final String id;
  final String name;
  final String businessType;
  final DateTime bookkeepingStartDate;
  final String createdBy;
  final String? logoUrl;
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
    this.logoUrl = '',
  });
  final String name;
  final String businessType;
  final DateTime bookkeepingStartDate;
  final String address;
  final String phoneNumber;
  final String email;
  final String logoUrl;

  String? validate() =>
      CompanyValidators.name(name) ??
      (CompanyValidators.businessTypes.contains(businessType)
          ? null
          : 'Pilih jenis usaha.') ??
      CompanyValidators.date(bookkeepingStartDate) ??
      CompanyValidators.address(address) ??
      AuthValidators.phone(phoneNumber) ??
      CompanyValidators.email(email) ??
      CompanyValidators.logo(logoUrl);
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
  static String? logo(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final url = Uri.tryParse(value.trim());
    return value.trim().length <= 2048 &&
            url != null &&
            url.scheme == 'https' &&
            url.host.isNotEmpty &&
            url.userInfo.isEmpty
        ? null
        : 'Gunakan URL gambar HTTPS yang valid (maksimal 2048 karakter).';
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
