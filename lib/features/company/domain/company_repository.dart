import 'company.dart';

abstract interface class CompanyRepository {
  Stream<CompanyContext?> watchMembership(String uid);
  Future<void> createCompany(CompanyDraft draft);

  /// Hanya Manager; `null` menghapus logo.
  Future<void> updateLogo(String companyId, String? logoSvg);
  Future<List<CompanyInvitation>> invitations({String? companyId});
  Future<void> inviteFinance(String companyId, String email);
  Future<void> cancelInvitation(String invitationId);
  Future<void> respondToInvitation(String invitationId, {required bool accept});
  Future<bool> refreshVerifiedEmail();
  Future<void> sendVerificationEmail();
}
