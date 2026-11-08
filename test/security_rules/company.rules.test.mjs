import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, test } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, updateDoc, collection, query, where, getDocs,
  writeBatch, serverTimestamp, Timestamp, runTransaction, deleteDoc } from 'firebase/firestore';

// Project demo khusus lokal; tidak pernah memakai finova-8592e.
let env;
const projectId = 'demo-finova-onboarding';
const email = (uid) => `${uid}@example.com`;
const db = (uid, verified = true) => env.authenticatedContext(uid,
  { email: email(uid), email_verified: verified }).firestore();
const profile = (uid, completed = true) => ({ uid, displayName: 'Nama Pengguna',
  email: email(uid), photoUrl: null, profileCompleted: completed,
  createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
const company = (uid) => ({ name: 'Finova Sejahtera', businessType: 'Jasa',
  bookkeepingStartDate: Timestamp.fromDate(new Date('2026-01-01T00:00:00Z')),
  address: '', phoneNumber: '', email: '', logoSvg: null, currency: 'IDR',
  createdBy: uid, status: 'active', createdAt: serverTimestamp(), updatedAt: serverTimestamp() });
const member = (uid, role = 'manager') => ({ uid, role, status: 'active', joinedAt: serverTimestamp() });
const access = (uid, companyId) => ({ uid, companyId, createdAt: serverTimestamp() });
function bootstrap(store, uid, changes = {}) {
  const batch = writeBatch(store);
  batch.set(doc(store, 'companies', uid), { ...company(uid), ...changes });
  batch.set(doc(store, 'companies', uid, 'members', uid), member(uid));
  batch.set(doc(store, 'company_access', uid), access(uid, uid));
  return batch.commit();
}
async function seedProfile(uid, completed = true) {
  await env.withSecurityRulesDisabled(async (ctx) => setDoc(
    doc(ctx.firestore(), 'users', uid), profile(uid, completed)));
}
async function seedCompany(uid = 'manager') {
  await seedProfile(uid);
  await assertSucceeds(bootstrap(db(uid), uid));
}
function inviteData() {
  return { companyId: 'manager', companyName: 'Finova Sejahtera',
    email: email('finance'), role: 'finance', status: 'pending', createdBy: 'manager',
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(), acceptedBy: null };
}
async function seedInvitation() {
  await seedCompany();
  await seedProfile('finance');
  await assertSucceeds(setDoc(doc(db('manager'), 'company_invitations', 'invite'), inviteData()));
}
function accept(store, uid = 'finance', role = 'finance', invitationId = 'invite') {
  const batch = writeBatch(store);
  batch.update(doc(store, 'company_invitations', invitationId), {
    status: 'accepted', acceptedBy: uid, updatedAt: serverTimestamp() });
  batch.set(doc(store, 'companies', 'manager', 'members', uid), {
    ...member(uid, role), invitationId });
  batch.set(doc(store, 'company_access', uid), access(uid, 'manager'));
  return batch.commit();
}

before(async () => {
  env = await initializeTestEnvironment({ projectId, firestore: {
    host: '127.0.0.1', port: 8085,
    rules: await readFile(new URL('../../firestore.rules', import.meta.url), 'utf8'),
  } });
});
beforeEach(async () => env.clearFirestore());
after(async () => env?.cleanup());

test('Profil lama tetap dapat diselesaikan, UID/role/email tidak dapat dipalsukan', async () => {
  const store = db('alice');
  await assertSucceeds(setDoc(doc(store, 'users', 'alice'), profile('alice', false)));
  await assertSucceeds(updateDoc(doc(store, 'users', 'alice'), {
    displayName: 'Alice Wijaya', phoneNumber: '+628123456789',
    profileCompleted: true, updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(store, 'users', 'alice'), { role: 'manager', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(store, 'users', 'alice'), { uid: 'bob', updatedAt: serverTimestamp() }));
  await assertFails(getDoc(doc(db('bob'), 'users', 'alice')));
});
test('Bootstrap atomik perusahaan + Manager + akses sendiri diizinkan', async () => {
  await seedCompany('alice');
  await assertSucceeds(getDoc(doc(db('alice'), 'companies', 'alice')));
  await assertSucceeds(getDoc(doc(db('alice'), 'companies', 'alice', 'members', 'alice')));
});
test('Profil belum lengkap dan anonim tidak dapat bootstrap', async () => {
  await seedProfile('alice', false);
  await assertFails(bootstrap(db('alice'), 'alice'));
  await assertFails(bootstrap(env.unauthenticatedContext().firestore(), 'anon'));
});
test('Perusahaan/Manager/link parsial dan field otorisasi tambahan ditolak', async () => {
  await seedProfile('alice');
  const store = db('alice');
  await assertFails(setDoc(doc(store, 'companies', 'alice'), company('alice')));
  await assertFails(setDoc(doc(store, 'company_access', 'alice'), access('alice', 'alice')));
  await assertFails(setDoc(doc(store, 'companies', 'alice', 'members', 'alice'), member('alice')));
  await assertFails(bootstrap(store, 'alice', { owner: true }));
  await assertFails(bootstrap(store, 'alice', { createdBy: 'other' }));
  await assertFails(bootstrap(store, 'alice', { name: '  ' }));
  await assertFails(bootstrap(store, 'alice', { currency: 'USD' }));
  await assertFails(bootstrap(store, 'alice', { logoSvg: '<svg onload="x()"></svg>' }));
});
test('Pengguna tidak dapat menjadi Manager di perusahaan orang lain atau membaca datanya', async () => {
  await seedCompany(); await seedProfile('attacker');
  const store = db('attacker'); const batch = writeBatch(store);
  batch.set(doc(store, 'companies', 'manager', 'members', 'attacker'), member('attacker'));
  batch.set(doc(store, 'company_access', 'attacker'), access('attacker', 'manager'));
  await assertFails(batch.commit());
  await assertFails(getDoc(doc(store, 'companies', 'manager')));
  await assertFails(getDocs(collection(store, 'companies')));
  await assertFails(setDoc(doc(db('manager'), 'companies', 'manager', 'transactions', 't1'), { amount: 1 }));
});
test('Retry bootstrap tidak overwrite perusahaan/membership dan link tidak bisa dipindah', async () => {
  await seedCompany('alice');
  await assertFails(bootstrap(db('alice'), 'alice'));
  await assertFails(updateDoc(doc(db('alice'), 'company_access', 'alice'), { companyId: 'other' }));
  await assertFails(updateDoc(doc(db('alice'), 'companies', 'alice', 'members', 'alice'), { role: 'finance' }));
});
test('Manager mengundang Finance; penerima terverifikasi dapat menemukan undangan melalui query', async () => {
  await seedInvitation();
  const recipient = db('finance');
  await assertSucceeds(getDocs(query(collection(recipient, 'company_invitations'), where('email', '==', email('finance')))));
  await assertSucceeds(getDocs(query(collection(db('manager'), 'company_invitations'), where('companyId', '==', 'manager'))));
  await assertFails(getDocs(collection(recipient, 'company_invitations')));
  await assertFails(getDoc(doc(recipient, 'companies', 'manager')));
});
test('Undangan tidak boleh dibuat non-Manager, menggunakan role Manager atau memalsukan perusahaan', async () => {
  await seedInvitation();
  await assertFails(setDoc(doc(db('finance'), 'company_invitations', 'fake'), { ...inviteData(), createdBy: 'finance' }));
  await assertFails(setDoc(doc(db('manager'), 'company_invitations', 'fake'), { ...inviteData(), role: 'manager' }));
  await assertFails(setDoc(doc(db('manager'), 'company_invitations', 'fake'), { ...inviteData(), companyName: 'Palsu' }));
});
test('Penerimaan atomik membuat Finance aktif dan membuka hanya perusahaan yang diundang', async () => {
  await seedInvitation();
  await assertSucceeds(accept(db('finance')));
  await assertSucceeds(getDoc(doc(db('finance'), 'companies', 'manager')));
  await seedCompany('other');
  await assertFails(getDoc(doc(db('finance'), 'companies', 'other')));
  await assertFails(accept(db('finance')));
});
test('Finance tidak dapat mengubah role, memindahkan membership atau membuat Manager', async () => {
  await seedInvitation(); await assertSucceeds(accept(db('finance')));
  const store = db('finance');
  await assertFails(updateDoc(doc(store, 'companies', 'manager', 'members', 'finance'), { role: 'manager' }));
  await assertFails(setDoc(doc(store, 'companies', 'manager', 'members', 'another'), member('another')));
  await assertFails(bootstrap(store, 'finance'));
  await assertFails(setDoc(doc(store, 'company_invitations', 'fake'), { ...inviteData(), createdBy: 'finance' }));
});
test('Pengguna salah dan email belum terverifikasi ditolak saat membaca/menerima undangan', async () => {
  await seedInvitation(); await seedProfile('attacker');
  await assertFails(accept(db('attacker'), 'attacker'));
  await assertFails(getDoc(doc(db('attacker'), 'company_invitations', 'invite')));
  await assertFails(accept(db('finance', false)));
  await assertFails(getDoc(doc(db('finance', false), 'company_invitations', 'invite')));
});
test('Tidak dapat menerima parsial, menaikkan role melalui undangan, atau reuse undangan dibatalkan', async () => {
  await seedInvitation();
  await assertFails(updateDoc(doc(db('finance'), 'company_invitations', 'invite'), {
    status: 'accepted', acceptedBy: 'finance', updatedAt: serverTimestamp() }));
  await assertFails(accept(db('finance'), 'finance', 'manager'));
  await assertSucceeds(updateDoc(doc(db('manager'), 'company_invitations', 'invite'), {
    status: 'cancelled', updatedAt: serverTimestamp() }));
  await assertFails(accept(db('finance')));
});
test('Penerima dapat menolak; penolakan tidak membuat membership dan tidak bisa diulang', async () => {
  await seedInvitation();
  await assertSucceeds(updateDoc(doc(db('finance'), 'company_invitations', 'invite'), {
    status: 'rejected', updatedAt: serverTimestamp() }));
  await assertFails(accept(db('finance')));
  await assertFails(getDoc(doc(db('finance'), 'companies', 'manager')));
});

test('Whitelist member dan access link menolak field otorisasi tambahan pada bootstrap', async () => {
  await seedProfile('alice');
  const store = db('alice');
  for (const target of ['member', 'access']) {
    const batch = writeBatch(store);
    batch.set(doc(store, 'companies', 'alice'), company('alice'));
    batch.set(doc(store, 'companies', 'alice', 'members', 'alice'), {
      ...member('alice'), ...(target === 'member' ? { permissions: ['all'] } : {}) });
    batch.set(doc(store, 'company_access', 'alice'), {
      ...access('alice', 'alice'), ...(target === 'access' ? { role: 'manager' } : {}) });
    await assertFails(batch.commit());
  }
});
test('Finance tidak dapat bergabung hanya dengan member/link tanpa undangan pending', async () => {
  await seedCompany(); await seedProfile('finance');
  const store = db('finance'); const batch = writeBatch(store);
  batch.set(doc(store, 'companies', 'manager', 'members', 'finance'), member('finance', 'finance'));
  batch.set(doc(store, 'company_access', 'finance'), access('finance', 'manager'));
  await assertFails(batch.commit());
  await assertFails(getDoc(doc(store, 'companies', 'manager')));
});
test('Email, companyId, role, createdBy dan field tambahan undangan tidak dapat diubah', async () => {
  await seedInvitation();
  for (const changes of [{ email: email('attacker') }, { companyId: 'other' },
    { role: 'manager' }, { createdBy: 'finance' }, { permissions: ['all'] }]) {
    for (const uid of ['manager', 'finance']) {
      await assertFails(updateDoc(doc(db(uid), 'company_invitations', 'invite'), {
        ...changes, updatedAt: serverTimestamp() }));
    }
  }
});
test('Manager perusahaan lain tidak dapat membaca/membatalkan undangan atau menulis member lintas perusahaan', async () => {
  await seedInvitation(); await seedCompany('other');
  const store = db('other');
  await assertFails(getDoc(doc(store, 'company_invitations', 'invite')));
  await assertFails(updateDoc(doc(store, 'company_invitations', 'invite'), {
    status: 'cancelled', updatedAt: serverTimestamp() }));
  await assertFails(setDoc(doc(store, 'company_invitations', 'forged'), {
    ...inviteData(), createdBy: 'other' }));
  await assertFails(setDoc(doc(store, 'companies', 'manager', 'members', 'other'), member('other')));
});

const chartCodes = ['1000', '1100', '1200', '1300', '1400', '2000', '2100', '2200',
  '3000', '3100', '3200', '4000', '4100', '4200', '4900', '5000', '5100', '5200',
  '5300', '5400', '5500', '5600', '5900'];
function chartAccount(code, creator = 'manager') {
  const type = { 1: 'asset', 2: 'liability', 3: 'equity', 4: 'revenue', 5: 'expense' }[code[0]];
  const group = `${code[0]}000`;
  return { code, name: `Akun ${code}`, type,
    normalBalance: ['asset', 'expense'].includes(type) ? 'debit' : 'credit',
    parentCode: code === group ? null : group, isPosting: code !== group,
    isActive: true, createdBy: creator, createdAt: serverTimestamp(), updatedAt: serverTimestamp() };
}
const chartRef = (store, code, companyId = 'manager') => doc(store, 'companies', companyId, 'chart_of_accounts', code);
async function initializeChart(store) {
  return runTransaction(store, async (transaction) => {
    const snapshots = [];
    for (const code of chartCodes) snapshots.push(await transaction.get(chartRef(store, code)));
    let created = 0;
    for (let i = 0; i < chartCodes.length; i++) {
      if (!snapshots[i].exists()) {
        transaction.set(chartRef(store, chartCodes[i]), chartAccount(chartCodes[i]));
        created++;
      }
    }
    return created;
  });
}
test('COA: Manager dapat menyiapkan 23 akun dan retry/concurrent initialization idempoten', async () => {
  await seedCompany();
  const store = db('manager');
  const counts = await assertSucceeds(Promise.all([initializeChart(store), initializeChart(store)]));
  if (counts.reduce((a, b) => a + b, 0) !== 23) throw new Error('Inisialisasi tidak idempoten');
  await assertSucceeds(initializeChart(store));
  const snapshot = await assertSucceeds(getDocs(collection(store, 'companies', 'manager', 'chart_of_accounts')));
  if (snapshot.size !== 23) throw new Error('Jumlah akun tidak sesuai');
});
test('COA: Finance aktif membaca daftar tetapi tidak membuat, memperbarui atau menghapus akun', async () => {
  await seedInvitation(); await assertSucceeds(accept(db('finance')));
  await assertSucceeds(initializeChart(db('manager')));
  const store = db('finance');
  await assertSucceeds(getDoc(chartRef(store, '4100')));
  await assertSucceeds(getDocs(collection(store, 'companies', 'manager', 'chart_of_accounts')));
  await assertFails(setDoc(chartRef(store, '4400'), chartAccount('4400', 'finance')));
  await assertFails(updateDoc(chartRef(store, '4100'), { name: 'Diubah Finance', updatedAt: serverTimestamp() }));
  await assertFails(deleteDoc(chartRef(store, '4100')));
});
test('COA: akun lintas perusahaan, anonim, membership nonaktif dan profil belum lengkap ditolak', async () => {
  await seedCompany(); await seedCompany('other'); await seedInvitationForChartFinance();
  const anonymous = env.unauthenticatedContext().firestore();
  for (const store of [db('other'), anonymous]) {
    await assertFails(getDoc(chartRef(store, '1000')));
    await assertFails(getDocs(collection(store, 'companies', 'manager', 'chart_of_accounts')));
    await assertFails(setDoc(chartRef(store, '1000'), chartAccount('1000')));
  }
  await env.withSecurityRulesDisabled(async (ctx) => updateDoc(
    doc(ctx.firestore(), 'companies', 'manager', 'members', 'finance'), { status: 'inactive' }));
  await assertFails(getDocs(collection(db('finance'), 'companies', 'manager', 'chart_of_accounts')));
  await env.withSecurityRulesDisabled(async (ctx) => updateDoc(doc(ctx.firestore(), 'users', 'manager'), { profileCompleted: false }));
  await assertFails(getDoc(chartRef(db('manager'), '1000')));
});
async function seedInvitationForChartFinance() {
  await seedProfile('finance');
  await assertSucceeds(setDoc(doc(db('manager'), 'company_invitations', 'invite'), inviteData()));
  await assertSucceeds(accept(db('finance')));
}
test('COA: schema menolak saldo/otorisasi tambahan, tipe dan saldo normal tidak sesuai', async () => {
  await seedCompany();
  const store = db('manager');
  for (const changes of [{ balance: 1000 }, { role: 'manager' }, { currency: 'USD' },
    { code: '2000' }, { type: 'unknown' }, { normalBalance: 'credit' }, { name: ' ' },
    { name: ' A ' }, { name: 'A\nB' }, { createdBy: 'other' }, { isActive: false }]) {
    await assertFails(setDoc(chartRef(store, '1000'), { ...chartAccount('1000'), ...changes }));
  }
});
test('COA: posting memerlukan induk sesuai pada perusahaan yang sama, getAfter menerima batch valid', async () => {
  await seedCompany(); const store = db('manager');
  await assertFails(setDoc(chartRef(store, '4100'), chartAccount('4100')));
  const batch = writeBatch(store);
  batch.set(chartRef(store, '4000'), chartAccount('4000'));
  batch.set(chartRef(store, '4100'), chartAccount('4100'));
  await assertSucceeds(batch.commit());
  await assertFails(setDoc(chartRef(store, '4200'), { ...chartAccount('4200'), parentCode: '5000' }));
  await assertFails(setDoc(chartRef(store, '4300'), { ...chartAccount('4300'), parentCode: '4300' }));
  await assertFails(updateDoc(chartRef(store, '4100'), { type: 'expense', normalBalance: 'debit', updatedAt: serverTimestamp() }));
  await assertFails(deleteDoc(chartRef(store, '4000')));
});
test('COA: perusahaan nonaktif dan collection transaksi/ledger tetap tertutup', async () => {
  await seedCompany(); const store = db('manager');
  for (const name of ['transactions', 'ledger']) {
    await assertFails(setDoc(doc(store, 'companies', 'manager', name, 'entry'), { amount: 100 }));
    await assertFails(getDocs(collection(store, 'companies', 'manager', name)));
  }
  await env.withSecurityRulesDisabled(async (ctx) => updateDoc(doc(ctx.firestore(), 'companies', 'manager'), { status: 'inactive' }));
  await assertFails(getDocs(collection(store, 'companies', 'manager', 'chart_of_accounts')));
  await assertFails(setDoc(chartRef(store, '1000'), chartAccount('1000')));
});

const svgLogo = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10"/></svg>';
test('Logo SVG: hanya Manager yang dapat mengganti; script, on*, dan >50 KB ditolak', async () => {
  await seedInvitation(); await assertSucceeds(accept(db('finance')));
  const ref = (store) => doc(store, 'companies', 'manager');
  const logo = (logoSvg) => ({ logoSvg, updatedAt: serverTimestamp() });
  await assertSucceeds(updateDoc(ref(db('manager')), logo(svgLogo)));
  await assertSucceeds(updateDoc(ref(db('manager')), logo(null)));
  await assertFails(updateDoc(ref(db('finance')), logo(svgLogo)));
  await assertFails(updateDoc(ref(env.unauthenticatedContext().firestore()), logo(svgLogo)));
  for (const bad of ['<svg><script>alert(1)</script></svg>', '<SVG><SCRIPT/></SVG>',
    '<svg onload="x()"></svg>', '<svg><rect\nonclick = "x()"/></svg>', 'bukan svg',
    `<svg>${'a'.repeat(51200)}</svg>`]) {
    await assertFails(updateDoc(ref(db('manager')), logo(bad)));
  }
  await assertFails(updateDoc(ref(db('manager')), { ...logo(svgLogo), name: 'Diubah' }));
  await assertFails(updateDoc(ref(db('manager')), { logoSvg: svgLogo }));
});
