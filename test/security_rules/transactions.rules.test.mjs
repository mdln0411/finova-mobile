import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, test } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, getDocs, updateDoc, deleteDoc, collection,
  serverTimestamp, Timestamp, writeBatch } from 'firebase/firestore';

// Project demo khusus lokal; tidak pernah memakai finova-8592e.
let env;
const projectId = 'demo-finova-onboarding';
const companyId = 'manager';
const db = (uid) => env.authenticatedContext(uid,
  { email: `${uid}@example.com`, email_verified: true }).firestore();
const anonymous = () => env.unauthenticatedContext().firestore();
const txRef = (store, id = 'tx1', company = companyId) =>
  doc(store, 'companies', company, 'transactions', id);
const day = (iso) => Timestamp.fromDate(new Date(`${iso}T00:00:00Z`));
const today = () => Timestamp.fromDate(new Date(new Date().toISOString().slice(0, 10) + 'T00:00:00Z'));

function tx(createdBy, changes = {}) {
  return { type: 'expense', amount: 150000, date: today(), description: 'Beli ATK',
    cashAccountId: '1100', categoryAccountId: '5900', status: 'pending', createdBy,
    createdAt: serverTimestamp(), approvedBy: null, approvedAt: null, rejectReason: null,
    ...changes };
}
const approve = (uid) => ({ status: 'approved', approvedBy: uid, approvedAt: serverTimestamp() });
const reject = (uid, reason = 'Bukti tidak lengkap') => ({ status: 'rejected',
  approvedBy: uid, approvedAt: serverTimestamp(), rejectReason: reason });

const accounts = { '1000': ['asset', false], '1100': ['asset', true], '1200': ['asset', true],
  '1300': ['asset', true], '2000': ['liability', false], '2100': ['liability', true],
  '4000': ['revenue', false], '4100': ['revenue', true], '5000': ['expense', false],
  '5900': ['expense', true], '5800': ['expense', true, false] };

async function seed() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const store = ctx.firestore();
    const now = Timestamp.now();
    for (const [uid, companyOf, role] of [['manager', companyId, 'manager'],
      ['finance', companyId, 'finance'], ['finance2', companyId, 'finance'],
      ['other', 'other', 'manager']]) {
      await setDoc(doc(store, 'users', uid), { uid, displayName: 'Nama', email: `${uid}@example.com`,
        photoUrl: null, profileCompleted: true, createdAt: now, updatedAt: now });
      await setDoc(doc(store, 'company_access', uid), { uid, companyId: companyOf, createdAt: now });
      await setDoc(doc(store, 'companies', companyOf, 'members', uid),
        { uid, role, status: 'active', joinedAt: now });
    }
    for (const id of [companyId, 'other']) {
      await setDoc(doc(store, 'companies', id), { name: 'Finova', businessType: 'Jasa',
        bookkeepingStartDate: day('2026-01-01'), address: '', phoneNumber: '', email: '',
        logoSvg: null, currency: 'IDR', createdBy: id, status: 'active', createdAt: now, updatedAt: now });
    }
    for (const [code, [type, isPosting, isActive = true]] of Object.entries(accounts)) {
      const group = `${code[0]}000`;
      await setDoc(doc(store, 'companies', companyId, 'chart_of_accounts', code), { code,
        name: `Akun ${code}`, type, normalBalance: ['asset', 'expense'].includes(type) ? 'debit' : 'credit',
        parentCode: isPosting ? group : null, isPosting, isActive, createdBy: 'manager',
        createdAt: now, updatedAt: now });
    }
  });
}
async function seedTx(id, data) {
  await env.withSecurityRulesDisabled(async (ctx) => setDoc(
    txRef(ctx.firestore(), id), { ...data, createdAt: Timestamp.now() }));
}
async function seedReceivable(id, data) {
  await env.withSecurityRulesDisabled(async (ctx) => setDoc(
    doc(ctx.firestore(), 'companies', companyId, 'receivables', id),
    { customerName: 'Customer Finova', number: 'INV-001', amount: 150000,
      revenueAccountId: '4100',
      dueDate: day('2026-03-01'), description: '', status: 'approved',
      createdBy: 'finance', createdAt: Timestamp.now(), approvedBy: 'manager',
      approvedAt: Timestamp.now(), rejectReason: null, ...data }));
}

before(async () => {
  env = await initializeTestEnvironment({ projectId, firestore: {
    host: '127.0.0.1', port: 8085,
    rules: await readFile(new URL('../../firestore.rules', import.meta.url), 'utf8'),
  } });
});
beforeEach(async () => { await env.clearFirestore(); await seed(); });
after(async () => env?.cleanup());

test('TX: Finance dan Manager aktif dapat membuat transaksi pending dan membaca daftar', async () => {
  await assertSucceeds(setDoc(txRef(db('finance'), 'f1'), tx('finance')));
  await assertSucceeds(setDoc(txRef(db('manager'), 'm1'), tx('manager',
    { type: 'income', categoryAccountId: '4100', cashAccountId: '1200' })));
  await assertSucceeds(getDoc(txRef(db('manager'), 'f1')));
  await assertSucceeds(getDocs(collection(db('finance'), 'companies', companyId, 'transactions')));
});

test('TX: status awal wajib pending dan field keputusan/pembuat tidak dapat dipalsukan', async () => {
  const store = db('finance');
  for (const changes of [{ status: 'approved' }, { status: 'rejected' }, { createdBy: 'manager' },
    { approvedBy: 'manager' }, { approvedAt: serverTimestamp() }, { rejectReason: 'x' },
    { createdAt: Timestamp.now() }, { ledgerPosted: true }]) {
    await assertFails(setDoc(txRef(store, 'bad'), tx('finance', changes)));
  }
  const { rejectReason, ...missing } = tx('finance');
  await assertFails(setDoc(txRef(store, 'bad'), missing));
});

test('TX: validasi nominal, tanggal, keterangan, tipe dan akun COA', async () => {
  const store = db('finance');
  const future = Timestamp.fromMillis(Date.now() + 3 * 86400000);
  for (const changes of [{ amount: 0 }, { amount: -1000 }, { amount: 1500.5 }, { amount: '1000' },
    { amount: 1e15 }, { date: future }, { date: day('2025-12-31') }, { date: '2026-02-01' },
    { description: '' }, { description: '   ' }, { description: 'a'.repeat(201) },
    { type: 'transfer' },
    { cashAccountId: '1300' }, { cashAccountId: '1000' }, { cashAccountId: '9999' },
    { cashAccountId: '2100' }, { categoryAccountId: '4100' }, { categoryAccountId: '5000' },
    { categoryAccountId: '5800' }, { categoryAccountId: '1100' },
    { type: 'income', categoryAccountId: '5900' }]) {
    await assertFails(setDoc(txRef(store, 'bad'), tx('finance', changes)));
  }
  await assertSucceeds(setDoc(txRef(store, 'ok'), tx('finance', { date: day('2026-01-01') })));
});

test('TX: pembayaran piutang memakai akun Piutang dan hanya untuk piutang approved', async () => {
  await seedReceivable('approved', {});
  await seedReceivable('pending', { status: 'pending', approvedBy: null, approvedAt: null });
  const payment = tx('finance', {
    type: 'income',
    categoryAccountId: '1300',
    cashAccountId: '1100',
    receivableId: 'approved',
  });
  await assertSucceeds(setDoc(txRef(db('finance'), 'payment'), payment));
  await assertFails(setDoc(txRef(db('finance'), 'without-link'), tx('finance', {
    type: 'income',
    categoryAccountId: '1300',
    cashAccountId: '1100',
  })));
  await assertFails(setDoc(txRef(db('finance'), 'pending-link'), {
    ...payment,
    receivableId: 'pending',
  }));
  await assertFails(setDoc(txRef(db('finance'), 'missing-link'), {
    ...payment,
    receivableId: 'missing',
  }));
  await assertFails(setDoc(txRef(db('finance'), 'wrong-type'), {
    ...payment,
    type: 'expense',
  }));
});

test('TX: persetujuan Piutang mencatat jurnal Piutang dan Pendapatan secara atomik', async () => {
  await seedReceivable('recognition', {
    status: 'pending',
    approvedBy: null,
    approvedAt: null,
  });
  const store = db('manager');
  const batch = writeBatch(store);
  batch.update(doc(store, 'companies', companyId, 'receivables', 'recognition'), {
    status: 'approved',
    approvedBy: 'manager',
    approvedAt: serverTimestamp(),
    rejectReason: null,
  });
  batch.set(txRef(store, 'receivable-recognition'), tx('manager', {
    type: 'income',
    amount: 150000,
    date: serverTimestamp(),
    description: 'Pengakuan piutang INV-001',
    cashAccountId: '1300',
    categoryAccountId: '4100',
    receivableId: 'recognition',
    status: 'approved',
    createdBy: 'manager',
    createdAt: serverTimestamp(),
    approvedBy: 'manager',
    approvedAt: serverTimestamp(),
    rejectReason: null,
  }));
  await assertSucceeds(batch.commit());

  await seedReceivable('not-approved', {
    status: 'pending',
    approvedBy: null,
    approvedAt: null,
  });
  const invalidBatch = writeBatch(store);
  invalidBatch.set(txRef(store, 'receivable-not-approved'), tx('manager', {
    type: 'income',
    cashAccountId: '1300',
    categoryAccountId: '4100',
    receivableId: 'not-approved',
    status: 'approved',
    createdBy: 'manager',
    approvedBy: 'manager',
    approvedAt: serverTimestamp(),
    rejectReason: null,
  }));
  await assertFails(invalidBatch.commit());
});

test('TX: anonim, perusahaan lain dan membership nonaktif ditolak', async () => {
  await seedTx('t1', tx('finance'));
  for (const store of [anonymous(), db('other')]) {
    await assertFails(getDoc(txRef(store, 't1')));
    await assertFails(getDocs(collection(store, 'companies', companyId, 'transactions')));
    await assertFails(setDoc(txRef(store, 'x'), tx('other')));
  }
  await env.withSecurityRulesDisabled(async (ctx) => updateDoc(
    doc(ctx.firestore(), 'companies', companyId, 'members', 'finance'), { status: 'inactive' }));
  await assertFails(setDoc(txRef(db('finance'), 'x'), tx('finance')));
  await assertFails(updateDoc(txRef(db('finance'), 't1'), { amount: 5000 }));
  await assertFails(deleteDoc(txRef(db('finance'), 't1')));
});

test('TX: pembuat dapat edit/hapus saat pending; pengguna lain tidak', async () => {
  await seedTx('t1', tx('finance'));
  await seedTx('t2', tx('finance'));
  await assertSucceeds(updateDoc(txRef(db('finance'), 't1'),
    { amount: 200000, description: 'Beli kertas', type: 'income', categoryAccountId: '4100' }));
  await assertFails(updateDoc(txRef(db('finance2'), 't1'), { amount: 1 }));
  await assertFails(updateDoc(txRef(db('manager'), 't1'), { amount: 1 }));
  await assertFails(deleteDoc(txRef(db('finance2'), 't2')));
  await assertFails(deleteDoc(txRef(db('manager'), 't2')));
  await assertSucceeds(deleteDoc(txRef(db('finance'), 't2')));
});

test('TX: edit pembuat tetap divalidasi dan tidak dapat mengubah status/pembuat', async () => {
  await seedTx('t1', tx('finance'));
  const store = db('finance');
  for (const changes of [{ status: 'approved' }, { createdBy: 'finance2' },
    { approvedBy: 'finance' }, { rejectReason: 'x' }, { amount: 0 }, { categoryAccountId: '4100' },
    { cashAccountId: '1300' }, { extra: true }]) {
    await assertFails(updateDoc(txRef(store, 't1'), changes));
  }
});

test('TX: hanya Manager yang dapat approve/reject; reject wajib alasan', async () => {
  for (const id of ['a', 'r', 'f']) await seedTx(id, tx('finance'));
  await assertFails(updateDoc(txRef(db('finance'), 'f'), approve('finance')));
  await assertFails(updateDoc(txRef(db('finance'), 'f'), reject('finance')));
  await assertFails(updateDoc(txRef(db('other'), 'f'), approve('other')));
  await assertFails(updateDoc(txRef(db('manager'), 'a'), approve('finance')));
  await assertFails(updateDoc(txRef(db('manager'), 'a'), { ...approve('manager'), amount: 1 }));
  await assertFails(updateDoc(txRef(db('manager'), 'a'), { ...approve('manager'), rejectReason: 'x' }));
  await assertFails(updateDoc(txRef(db('manager'), 'a'), { status: 'approved', approvedBy: 'manager',
    approvedAt: Timestamp.now() }));
  await assertFails(updateDoc(txRef(db('manager'), 'a'), { ...approve('manager'), status: 'pending' }));
  await assertSucceeds(updateDoc(txRef(db('manager'), 'a'), approve('manager')));
  for (const reason of [null, '', '  ', 'ab', 'a'.repeat(501)]) {
    await assertFails(updateDoc(txRef(db('manager'), 'r'), reject('manager', reason)));
  }
  await assertSucceeds(updateDoc(txRef(db('manager'), 'r'), reject('manager')));
});

test('TX: transaksi approved/rejected tidak dapat diubah, diputuskan ulang, atau dihapus', async () => {
  await seedTx('a', tx('finance', { status: 'approved', approvedBy: 'manager', approvedAt: Timestamp.now() }));
  await seedTx('r', tx('finance', { status: 'rejected', approvedBy: 'manager',
    approvedAt: Timestamp.now(), rejectReason: 'Salah akun' }));
  await seedTx('m', tx('manager', { status: 'approved', approvedBy: 'manager', approvedAt: Timestamp.now() }));
  for (const id of ['a', 'r']) {
    await assertFails(updateDoc(txRef(db('finance'), id), { amount: 1 }));
    await assertFails(deleteDoc(txRef(db('finance'), id)));
    await assertFails(deleteDoc(txRef(db('manager'), id)));
    await assertFails(setDoc(txRef(db('finance'), id), tx('finance')));
  }
  await assertFails(updateDoc(txRef(db('manager'), 'a'), reject('manager')));
  await assertFails(updateDoc(txRef(db('manager'), 'r'), { ...approve('manager'), rejectReason: null }));
  await assertFails(updateDoc(txRef(db('manager'), 'm'), { amount: 1 }));
  await assertFails(deleteDoc(txRef(db('manager'), 'm')));
});
