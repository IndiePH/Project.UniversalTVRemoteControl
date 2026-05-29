const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

const {
  assertProProductIdAllowed,
  assertTokenOwner,
  proProductKindFor,
  productIdFromSubscriptionV2,
  sha256Hex,
  subscriptionEntitlementFromV2,
} = require('../lib/index.js');

describe('Pro receipt validation helpers', () => {
  it('allows configured Pro products and classifies subscriptions', () => {
    assert.equal(proProductKindFor('sub_monthly'), 'subscription');
    assert.equal(proProductKindFor('sub_weekly'), 'subscription');
    assert.equal(proProductKindFor('lifetime'), 'lifetime');
    assert.doesNotThrow(() => assertProProductIdAllowed('sub_annually'));
  });

  it('rejects product IDs outside the Pro catalog', () => {
    assert.throws(
      () => assertProProductIdAllowed('coins_100'),
      /Unsupported Pro product ID/,
    );
  });

  it('does not throw when another uid owns the token but purchase is not entitled', () => {
    assert.doesNotThrow(() => assertTokenOwner(undefined, 'uid-1', false));
    assert.doesNotThrow(() => assertTokenOwner('uid-1', 'uid-1', false));
    assert.doesNotThrow(() => assertTokenOwner('uid-1', 'uid-2', false));
  });

  it('allows reclaiming a purchase token for restore when still entitled', () => {
    assert.doesNotThrow(() => assertTokenOwner('uid-1', 'uid-2', true));
  });

  it('hashes purchase tokens before persistence', () => {
    assert.equal(
      sha256Hex('purchase-token'),
      '3f955299b922937e8acf830313756fd3752c199963113835d81480dbf5aa2f27',
    );
  });

  it('treats active subscription v2 purchases as entitled', () => {
    const future = new Date(Date.now() + 60_000).toISOString();
    const result = subscriptionEntitlementFromV2({
      subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
      lineItems: [{ expiryTime: future }],
    });
    assert.equal(result.entitled, true);
    assert.equal(typeof result.expiresAtEpochMs, 'number');
  });

  it('rejects expired subscription v2 purchases', () => {
    const past = new Date(Date.now() - 60_000).toISOString();
    const result = subscriptionEntitlementFromV2({
      subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
      lineItems: [{ expiryTime: past }],
    });
    assert.equal(result.entitled, false);
  });

  it('reads subscription product id from v2 line items', () => {
    assert.equal(
      productIdFromSubscriptionV2({
        lineItems: [{ productId: 'sub_monthly' }],
      }),
      'sub_monthly',
    );
    assert.equal(productIdFromSubscriptionV2({ lineItems: [] }), null);
  });
});
