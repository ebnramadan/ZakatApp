const {test} = require('node:test');
const assert = require('node:assert/strict');
const {duePlans, dueDate, composeMessage} = require('../scripts/monthly-reminders.cjs');
const now = new Date('2026-02-28T08:00:00Z');
const plan = (id, patch={}) => ({id, recipient:'A recipient', amount:100, currency:'USD', kind:'sadaqah', reminderDay:31, startMonth:'2026-01', active:true, ...patch});
test('due reminders clamp month-end and skip future, paused, paid and already-reminded recipients', () => {
  const plans = [plan('due'),plan('paid'),plan('sent'),plan('paused',{active:false}),plan('future',{startMonth:'2026-03'})];
  const due = duePlans(plans, [{planId:'paid',month:'2026-02'}], [{planId:'sent',month:'2026-02',status:'sent'}], now);
  assert.deepEqual(due.map(p=>p.id),['due']);
  assert.equal(dueDate(plan('p'), now),28);
});
test('a new month generates a new reminder without counting last month as paid', () => {
  const due = duePlans([plan('p',{reminderDay:1})],[{planId:'p',month:'2026-01'}],[{planId:'p',month:'2026-01',status:'sent'}],now);
  assert.equal(due.length,1);
});
test('message separates Zakat/Sadaqah, does not combine currencies, and offers an opt out', () => {
  const message = composeMessage([plan('s'),plan('z',{kind:'zakat',currency:'EGP',amount:500})], now, 'https://zakat-app-36c58.web.app');
  assert.match(message.text,/USD 100.00 \(Sadaqah\)/);
  assert.match(message.text,/EGP 500.00 \(Zakat\)/);
  assert.match(message.text,/turn off email reminders/);
  assert.match(message.text,/does not transfer money/);
});
