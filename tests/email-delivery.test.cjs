const {test} = require('node:test');
const assert = require('node:assert/strict');
const {deliverEmail, sendDeliveryTest} = require('../scripts/email-delivery.cjs');

test('delivery test uses verified Auth address, contains no financial data and honors dry run', async () => {
  let calls = 0;
  const options = {testEmail: 'owner@example.com', auth: {getUserByEmail: async () => ({emailVerified: true, email: 'canonical@example.com'})}, log: () => {}};
  const sender = async () => ({send: async (to, message) => {
    calls++;
    assert.equal(to, 'canonical@example.com');
    assert.equal(message.attachments, undefined);
    assert.match(message.text, /no financial information/);
  }});
  await sendDeliveryTest({...options, dryRun: true}, sender);
  assert.equal(calls, 0);
  await sendDeliveryTest(options, sender);
  assert.equal(calls, 1);
  for (const account of [{emailVerified: false}, {emailVerified: true, disabled: true}]) {
    await assert.rejects(sendDeliveryTest({...options, auth: {getUserByEmail: async () => account}}, sender));
  }
  assert.equal(calls, 1);
});

test('every trigger processes requested, scheduled and reminder emails with the same dry-run setting', async () => {
  for (const dryRun of [true, false]) {
    const calls = [];
    const options = {dryRun, now: new Date(), db: {}, auth: {}};
    await deliverEmail(options, {
      sendProgressSheets: async o => calls.push([o.manualOnly ? 'requested' : 'scheduled', o]),
      sendReminders: async o => calls.push(['reminders', o]),
    });
    assert.deepEqual(calls.map(c => c[0]), ['requested', 'scheduled', 'reminders']);
    for (const [, o] of calls) {
      assert.equal(o.dryRun, dryRun);
      assert.equal(o.db, options.db);
      assert.equal(o.now, options.now);
    }
  }
});

test('one broken mail task does not starve the others, but fails the run without leaking provider errors', async () => {
  const calls = [], logs = [];
  await assert.rejects(deliverEmail({log: s => logs.push(s)}, {
    sendProgressSheets: async o => {
      calls.push(o.manualOnly ? 'requested' : 'scheduled');
      if (o.manualOnly) throw Error('private email and provider details');
    },
    sendReminders: async () => calls.push('reminders'),
  }), /Email delivery incomplete: requested sheets/);
  assert.deepEqual(calls, ['requested', 'scheduled', 'reminders']);
  assert.equal(logs.length, 1);
  assert.ok(!logs[0].includes('private email'));
});
