import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, test } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, getDocs, updateDoc, deleteDoc, collection,
  serverTimestamp, Timestamp, writeBatch } from 'firebase/firestore';

let env;
const projectId = 'demo-finova-onboarding';
const companyId = 'manager';
const db = (uid) => env.authenticatedContext(uid,
  { email: `${uid}@example.com`, email_verified: true }).firestore();
const anonymous = () => env.unauthenticatedContext().firestore();
const receivableRef = (store, id = 'r1', company = companyId) =>
  doc(store, 'companies', company, 'receivables', id);
const day = (iso) => Timestamp.fromDate(new Date(`${iso}T00:00:00Z`));

function receivable(createdBy, changes = {}) {
  return {
    customerName: 'Customer Finova',
    number: 'INV-001',
    amount: 150000,
    revenueAccountId: '4100',
    dueDate: day('2026-03-01'),
    description: 'Penjualan barang',
    status: 'pending',
    createdBy,
    createdAt: serverTimestamp(),
    approvedBy: null,
    approvedAt: null,
    rejectReason: null,
    ...changes,
  };
}

function recognition(receivableId, creator = 'manager') {
  return {
    type: 'income',
    amount: 150000,
    date: serverTimestamp(),
    description: 'Pengakuan piutang INV-001',
    cashAccountId: '1300',
    categoryAccountId: '4100',
    receivableId,
    status: 'approved',
    createdBy: creator,
    createdAt: serverTimestamp(),
    approvedBy: creator,
    approvedAt: serverTimestamp(),
    rejectReason: null,
  };
}

async function seed() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const store = ctx.firestore();
    const now = Timestamp.now();
    for (const [uid, companyOf, role] of [
      ['manager', companyId, 'manager'],
      ['finance', companyId, 'finance'],
      ['finance2', companyId, 'finance'],
      ['other', 'other', 'manager'],
    ]) {
      await setDoc(doc(store, 'users', uid), {
        uid,
        displayName: 'Nama Pengguna',
        email: `${uid}@example.com`,
        photoUrl: null,
        profileCompleted: true,
        createdAt: now,
        updatedAt: now,
      });
      await setDoc(doc(store, 'company_access', uid), {
        uid,
        companyId: companyOf,
        createdAt: now,
      });
      await setDoc(doc(store, 'companies', companyOf, 'members', uid), {
        uid,
        role,
        status: 'active',
        joinedAt: now,
      });
    }
    for (const id of [companyId, 'other']) {
      await setDoc(doc(store, 'companies', id), {
        name: 'Finova',
        businessType: 'Jasa',
        bookkeepingStartDate: day('2026-01-01'),
        address: '',
        phoneNumber: '',
        email: '',
        logoSvg: null,
        currency: 'IDR',
        createdBy: id,
        status: 'active',
        createdAt: now,
        updatedAt: now,
      });
    }
    for (const id of [companyId, 'other']) {
      await setDoc(doc(store, 'companies', id, 'chart_of_accounts', '4000'), {
        code: '4000',
        name: 'Pendapatan',
        type: 'revenue',
        normalBalance: 'credit',
        parentCode: null,
        isPosting: false,
        isActive: true,
        createdBy: 'manager',
        createdAt: now,
        updatedAt: now,
      });
      await setDoc(doc(store, 'companies', id, 'chart_of_accounts', '4100'), {
        code: '4100',
        name: 'Penjualan',
        type: 'revenue',
        normalBalance: 'credit',
        parentCode: '4000',
        isPosting: true,
        isActive: true,
        createdBy: 'manager',
        createdAt: now,
        updatedAt: now,
      });
    }
  });
}

async function seedReceivable(id, data) {
  await env.withSecurityRulesDisabled(async (ctx) => setDoc(
    receivableRef(ctx.firestore(), id),
    { ...data, createdAt: Timestamp.now() },
  ));
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: '127.0.0.1',
      port: 8085,
      rules: await readFile(new URL('../../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});
beforeEach(async () => {
  await env.clearFirestore();
  await seed();
});
after(async () => env?.cleanup());

test('Receivable: Finance dan Manager aktif membuat piutang berstatus pending', async () => {
  await assertSucceeds(setDoc(receivableRef(db('finance'), 'f1'), receivable('finance')));
  await assertSucceeds(setDoc(receivableRef(db('manager'), 'm1'), receivable('manager')));
  await assertSucceeds(getDoc(receivableRef(db('manager'), 'f1')));
  await assertSucceeds(getDocs(collection(db('finance'), 'companies', companyId, 'receivables')));
  for (const changes of [
    { status: 'approved' },
    { status: 'rejected' },
    { createdBy: 'manager' },
    { approvedBy: 'manager' },
    { approvedAt: serverTimestamp() },
    { amount: 0 },
    { amount: 1500.5 },
    { revenueAccountId: '4000' },
    { revenueAccountId: '1300' },
    { customerName: ' ' },
    { number: '' },
    { dueDate: day('2025-12-31') },
    { extra: true },
  ]) {
    await assertFails(setDoc(receivableRef(db('finance'), 'invalid'), receivable('finance', changes)));
  }
});

test('Receivable: pembuat mengedit atau menghapus hanya dokumen pending miliknya', async () => {
  await seedReceivable('r1', receivable('finance'));
  await seedReceivable('r2', receivable('finance'));
  await assertSucceeds(updateDoc(receivableRef(db('finance'), 'r1'), {
    amount: 175000,
    customerName: 'Customer Baru',
  }));
  await assertFails(updateDoc(receivableRef(db('finance2'), 'r2'), { amount: 1 }));
  await assertFails(updateDoc(receivableRef(db('manager'), 'r2'), { amount: 1 }));
  await assertFails(deleteDoc(receivableRef(db('manager'), 'r2')));
  await assertFails(deleteDoc(receivableRef(db('finance2'), 'r2')));
  await assertSucceeds(deleteDoc(receivableRef(db('finance'), 'r2')));
  await assertFails(updateDoc(receivableRef(db('finance'), 'r1'), {
    status: 'approved',
    amount: 100,
  }));
});

test('Receivable: hanya Manager aktif dapat approve atau reject pending', async () => {
  await seedReceivable('approve', receivable('finance'));
  await seedReceivable('reject', receivable('finance'));
  await assertFails(updateDoc(receivableRef(db('finance'), 'approve'), {
    status: 'approved',
    approvedBy: 'finance',
    approvedAt: serverTimestamp(),
    rejectReason: null,
  }));
  await assertFails(updateDoc(receivableRef(db('other'), 'approve'), {
    status: 'approved',
    approvedBy: 'other',
    approvedAt: serverTimestamp(),
    rejectReason: null,
  }));
  await assertFails(updateDoc(receivableRef(db('manager'), 'approve'), {
    status: 'approved',
    approvedBy: 'manager',
    approvedAt: serverTimestamp(),
    rejectReason: null,
  }));
  const store = db('manager');
  const approval = writeBatch(store);
  approval.update(receivableRef(store, 'approve'), {
    status: 'approved',
    approvedBy: 'manager',
    approvedAt: serverTimestamp(),
    rejectReason: null,
  });
  approval.set(
    doc(store, 'companies', companyId, 'transactions', 'receivable-approve'),
    recognition('approve'),
  );
  await assertSucceeds(approval.commit());
  await assertFails(updateDoc(receivableRef(db('manager'), 'reject'), {
    status: 'rejected',
    approvedBy: 'manager',
    approvedAt: serverTimestamp(),
    rejectReason: 'x',
  }));
  await assertSucceeds(updateDoc(receivableRef(db('manager'), 'reject'), {
    status: 'rejected',
    approvedBy: 'manager',
    approvedAt: serverTimestamp(),
    rejectReason: 'Nomor invoice tidak cocok',
  }));
});

test('Receivable: approved/rejected immutable; anggota nonaktif dan anonim ditolak', async () => {
  await seedReceivable('approved', receivable('finance', {
    status: 'approved',
    approvedBy: 'manager',
    approvedAt: Timestamp.now(),
  }));
  await seedReceivable('rejected', receivable('finance', {
    status: 'rejected',
    approvedBy: 'manager',
    approvedAt: Timestamp.now(),
    rejectReason: 'Data tidak cocok',
  }));
  for (const id of ['approved', 'rejected']) {
    await assertFails(updateDoc(receivableRef(db('finance'), id), { amount: 1 }));
    await assertFails(deleteDoc(receivableRef(db('finance'), id)));
    await assertFails(deleteDoc(receivableRef(db('manager'), id)));
  }
  await assertFails(getDoc(receivableRef(anonymous(), 'approved')));
  await env.withSecurityRulesDisabled(async (ctx) => updateDoc(
    doc(ctx.firestore(), 'companies', companyId, 'members', 'finance'),
    { status: 'inactive' },
  ));
  await assertFails(getDocs(collection(db('finance'), 'companies', companyId, 'receivables')));
  await assertFails(setDoc(receivableRef(db('finance'), 'new'), receivable('finance')));
});
