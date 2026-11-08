import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../auth/domain/auth_validators.dart';
import '../domain/company.dart';
import '../domain/company_repository.dart';

class FirebaseCompanyRepository implements CompanyRepository {
  FirebaseCompanyRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _providedStore = firestore,
      _providedAuth = auth;
  final FirebaseFirestore? _providedStore;
  final FirebaseAuth? _providedAuth;
  FirebaseFirestore get _store => _providedStore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _providedAuth ?? FirebaseAuth.instance;
  User get _user =>
      _auth.currentUser ??
      (throw const CompanyFailure('Sesi berakhir. Silakan masuk kembali.'));

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action().timeout(const Duration(seconds: 25));
    } on FirebaseException catch (error) {
      developer.log(
        'company_access code=${error.code}',
        name: 'finova.company',
      );
      throw CompanyFailure(switch (error.code) {
        'permission-denied' =>
          'Akses perusahaan ditolak. Periksa verifikasi email, membership, '
              'dan penerapan Firestore Rules bersama pengelola.',
        'unavailable' || 'network-request-failed' || 'deadline-exceeded' =>
          'Koneksi belum tersedia. Sambungkan internet lalu coba lagi.',
        'failed-precondition' =>
          'Data perusahaan belum siap. Coba muat ulang atau hubungi pengelola.',
        'too-many-requests' =>
          'Terlalu banyak permintaan. Coba beberapa saat lagi.',
        _ => 'Operasi perusahaan belum berhasil. Silakan coba lagi.',
      });
    } on TimeoutException {
      // Commit dapat selesai setelah timeout. Retry memakai link/ID yang sama.
      throw const CompanyFailure(
        'Server belum merespons. Coba lagi untuk memeriksa hasil penyimpanan.',
      );
    }
  }

  static CompanyContext parseContext(
    String companyId,
    String uid,
    Map<String, dynamic>? company,
    Map<String, dynamic>? member,
  ) {
    final role = member?['role'];
    final name = company?['name'];
    final date = company?['bookkeepingStartDate'];
    final creator = company?['createdBy'];
    final logo = company?['logoSvg'];
    if (company == null ||
        member == null ||
        company['status'] != 'active' ||
        member['status'] != 'active' ||
        member['uid'] != uid ||
        !['manager', 'finance'].contains(role) ||
        name is! String ||
        CompanyValidators.name(name) != null ||
        date is! Timestamp ||
        CompanyValidators.date(date.toDate()) != null ||
        creator is! String ||
        creator.isEmpty ||
        company['currency'] != 'IDR' ||
        !CompanyValidators.businessTypes.contains(company['businessType'])) {
      throw const CompanyFailure(
        'Membership atau data perusahaan tidak aktif/valid. Hubungi Manager.',
      );
    }
    return CompanyContext(
      company: Company(
        id: companyId,
        name: name,
        businessType: company['businessType'] as String,
        bookkeepingStartDate: date.toDate(),
        createdBy: creator,
        // Logo rusak tidak mengunci perusahaan; cukup kembali ke ikon bawaan.
        logoSvg: logo is String && CompanyValidators.logoSvg(logo) == null
            ? logo
            : null,
      ),
      role: role == 'manager' ? CompanyRole.manager : CompanyRole.finance,
    );
  }

  @override
  Stream<CompanyContext?> watchMembership(String uid) async* {
    if (_user.uid != uid) throw const CompanyFailure('Identitas sesi berubah.');
    final link = await _guard(
      () => _store
          .collection('company_access')
          .doc(uid)
          .get(const GetOptions(source: Source.server)),
    );
    if (!link.exists) {
      yield null;
      return;
    }
    final companyId = link.data()?['companyId'];
    if (link.data()?['uid'] != uid ||
        companyId is! String ||
        companyId.isEmpty ||
        companyId.contains('/')) {
      throw const CompanyFailure(
        'Referensi perusahaan tidak valid. Hubungi pengelola.',
      );
    }
    final companyRef = _store.collection('companies').doc(companyId);
    final stream = StreamController<CompanyContext?>();
    Map<String, dynamic>? company;
    Map<String, dynamic>? member;
    var companyReady = false;
    var memberReady = false;
    void emit() {
      if (!companyReady || !memberReady || stream.isClosed) return;
      try {
        stream.add(parseContext(companyId, uid, company, member));
      } catch (error) {
        stream.addError(error);
      }
    }

    void fail(Object error) {
      if (!stream.isClosed) {
        stream.addError(
          const CompanyFailure(
            'Membership belum dapat diverifikasi server. Periksa koneksi dan izin, lalu coba lagi.',
          ),
        );
      }
    }

    final companySub = companyRef
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
          if (snapshot.metadata.isFromCache ||
              snapshot.metadata.hasPendingWrites) {
            return;
          }
          company = snapshot.data();
          companyReady = true;
          emit();
        }, onError: fail);
    final memberSub = companyRef
        .collection('members')
        .doc(uid)
        .snapshots(includeMetadataChanges: true)
        .listen((snapshot) {
          if (snapshot.metadata.isFromCache ||
              snapshot.metadata.hasPendingWrites) {
            return;
          }
          member = snapshot.data();
          memberReady = true;
          emit();
        }, onError: fail);
    // Tidak membuka Dashboard dari cache atau write lokal yang belum disetujui.
    final timer = Timer(const Duration(seconds: 25), () {
      if (!companyReady || !memberReady) fail(TimeoutException('membership'));
    });
    try {
      yield* stream.stream;
    } finally {
      timer.cancel();
      await companySub.cancel();
      await memberSub.cancel();
      unawaited(stream.close());
    }
  }

  @override
  Future<void> createCompany(CompanyDraft draft) => _guard(() async {
    final error = draft.validate();
    if (error != null) throw CompanyFailure(error);
    final uid = _user.uid;
    final company = _store.collection('companies').doc(uid);
    final access = _store.collection('company_access').doc(uid);
    final profile = _store.collection('users').doc(uid);
    await _store.runTransaction((transaction) async {
      final link = await transaction.get(access);
      final user = (await transaction.get(profile)).data();
      if (user?['uid'] != uid || user?['profileCompleted'] != true) {
        throw const CompanyFailure('Lengkapi profil pribadi terlebih dahulu.');
      }
      // Link immutable adalah kunci idempotensi lintas retry/perangkat/restart.
      if (link.exists) return;
      transaction.set(company, {
        'name': draft.name.trim(),
        'businessType': draft.businessType,
        'bookkeepingStartDate': Timestamp.fromDate(
          DateTime.utc(
            draft.bookkeepingStartDate.year,
            draft.bookkeepingStartDate.month,
            draft.bookkeepingStartDate.day,
          ),
        ),
        'address': draft.address.trim(),
        'phoneNumber': AuthValidators.normalizePhone(draft.phoneNumber),
        'email': draft.email.trim(),
        'logoSvg': draft.logoSvg,
        'currency': 'IDR',
        'createdBy': uid,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(company.collection('members').doc(uid), {
        'uid': uid,
        'role': 'manager',
        'status': 'active',
        'joinedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(access, {
        'uid': uid,
        'companyId': company.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  });

  @override
  Future<void> updateLogo(String companyId, String? logoSvg) =>
      _guard(() async {
        final error = CompanyValidators.logoSvg(logoSvg);
        if (error != null) throw CompanyFailure(error);
        if (_auth.currentUser == null) {
          throw const CompanyFailure('Sesi berakhir. Silakan masuk kembali.');
        }
        await _store.collection('companies').doc(companyId).update({
          'logoSvg': logoSvg,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

  static CompanyInvitation parseInvitation(
    String id,
    Map<String, dynamic> data,
  ) {
    if (data['companyId'] is! String ||
        data['companyName'] is! String ||
        data['email'] is! String ||
        data['role'] != 'finance' ||
        ![
          'pending',
          'accepted',
          'rejected',
          'cancelled',
        ].contains(data['status'])) {
      throw const CompanyFailure(
        'Format undangan belum sesuai. Hubungi Manager.',
      );
    }
    return CompanyInvitation(
      id: id,
      companyId: data['companyId'] as String,
      companyName: data['companyName'] as String,
      email: data['email'] as String,
      status: data['status'] as String,
    );
  }

  @override
  Future<List<CompanyInvitation>> invitations({String? companyId}) =>
      _guard(() async {
        final query = _store
            .collection('company_invitations')
            .where(
              companyId == null ? 'email' : 'companyId',
              isEqualTo: companyId ?? _user.email!.toLowerCase(),
            );
        final result = await query.get(const GetOptions(source: Source.server));
        return result.docs
            .map((doc) => parseInvitation(doc.id, doc.data()))
            .where((invite) => invite.status == 'pending')
            .toList();
      });

  @override
  Future<void> inviteFinance(String companyId, String email) => _guard(
    () async {
      final normalized = email.trim().toLowerCase();
      final error = AuthValidators.email(normalized);
      if (error != null) throw CompanyFailure(error);
      if (normalized == _user.email?.toLowerCase()) {
        throw const CompanyFailure(
          'Undang akun Finance lain, bukan akun Anda sendiri.',
        );
      }
      // Deterministik per perusahaan/email; retry tidak menggandakan undangan.
      final id = Uri.encodeComponent('$companyId:$normalized');
      final reference = _store.collection('company_invitations').doc(id);
      final companyRef = _store.collection('companies').doc(companyId);
      await _store.runTransaction((transaction) async {
        final existing = await transaction.get(reference);
        final company = (await transaction.get(companyRef)).data();
        if (existing.exists) {
          if (existing.data()?['status'] == 'pending') return;
          throw const CompanyFailure(
            'Undangan email ini sudah diproses. Hubungi pengelola jika perlu mengundang ulang.',
          );
        }
        transaction.set(reference, {
          'companyId': companyId,
          'companyName': company?['name'],
          'email': normalized,
          'role': 'finance',
          'status': 'pending',
          'createdBy': _user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'acceptedBy': null,
        });
      });
    },
  );

  @override
  Future<void> cancelInvitation(String invitationId) => _guard(() async {
    await _store.collection('company_invitations').doc(invitationId).update({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });

  @override
  Future<void> respondToInvitation(
    String invitationId, {
    required bool accept,
  }) => _guard(() async {
    final user = _user;
    if (!await refreshVerifiedEmail()) {
      throw const CompanyFailure('Verifikasi email akun terlebih dahulu.');
    }
    final reference = _store
        .collection('company_invitations')
        .doc(invitationId);
    final access = _store.collection('company_access').doc(user.uid);
    await _store.runTransaction((transaction) async {
      final data = (await transaction.get(reference)).data();
      final link = await transaction.get(access);
      if (data == null || data['email'] != user.email?.toLowerCase()) {
        throw const CompanyFailure('Undangan tidak ditujukan ke akun ini.');
      }
      if (data['status'] == 'accepted' &&
          data['acceptedBy'] == user.uid &&
          link.data()?['companyId'] == data['companyId']) {
        return;
      }
      if (data['status'] != 'pending') {
        throw const CompanyFailure('Undangan sudah diproses atau dibatalkan.');
      }
      if (link.exists && accept) {
        throw const CompanyFailure('Akun Anda sudah terhubung ke perusahaan.');
      }
      transaction.update(reference, {
        'status': accept ? 'accepted' : 'rejected',
        'acceptedBy': accept ? user.uid : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (accept) {
        final company = _store
            .collection('companies')
            .doc(data['companyId'] as String);
        transaction.set(company.collection('members').doc(user.uid), {
          'uid': user.uid,
          'role': 'finance',
          'status': 'active',
          'invitationId': invitationId,
          'joinedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(access, {
          'uid': user.uid,
          'companyId': company.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  });

  @override
  Future<bool> refreshVerifiedEmail() => _guard(() async {
    await _user.reload();
    await _user.getIdToken(true);
    return _user.emailVerified;
  });

  @override
  Future<void> sendVerificationEmail() =>
      _guard(() => _user.sendEmailVerification());
}
