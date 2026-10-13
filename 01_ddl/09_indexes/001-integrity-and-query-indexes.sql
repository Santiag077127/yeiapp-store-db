--liquibase formatted sql
--changeset yeiapp:006-integrity-and-query-indexes
CREATE UNIQUE INDEX uq_app_user_email_ci ON identity.app_user (lower(email));
CREATE UNIQUE INDEX uq_product_offer_active_mode ON catalog.product_offer (product_id, sale_mode) WHERE status_code = 'ACTIVE';
CREATE UNIQUE INDEX uq_price_list_active_role ON catalog.price_list (target_role) WHERE status_code = 'ACTIVE';
CREATE UNIQUE INDEX uq_rah_subscription_sequence ON inventory.resource_assignment_history (subscription_id, sequence);
CREATE UNIQUE INDEX uq_rah_current_subscription ON inventory.resource_assignment_history (subscription_id) WHERE released_at IS NULL;
CREATE UNIQUE INDEX uq_rah_current_profile ON inventory.resource_assignment_history (profile_id) WHERE released_at IS NULL AND profile_id IS NOT NULL;
CREATE UNIQUE INDEX uq_rah_current_full_account ON inventory.resource_assignment_history (account_id) WHERE released_at IS NULL AND account_id IS NOT NULL;
CREATE UNIQUE INDEX uq_subscription_renewal_parent ON sales.subscription (previous_subscription_id) WHERE previous_subscription_id IS NOT NULL;
CREATE UNIQUE INDEX uq_wallet_tx_purchase_order ON wallet.wallet_transaction (order_id) WHERE type_code = 'PURCHASE_DEBIT';
CREATE UNIQUE INDEX uq_wallet_tx_reversal_original ON wallet.wallet_transaction (reversed_wallet_transaction_id) WHERE reversed_wallet_transaction_id IS NOT NULL;
CREATE UNIQUE INDEX uq_wallet_tx_sequence ON wallet.wallet_transaction (wallet_id, sequence_no);

ALTER TABLE inventory.resource_assignment_history
    ADD CONSTRAINT ex_rah_profile_time EXCLUDE USING gist (
        profile_id WITH =,
        tstzrange(assigned_at, released_at, '[)') WITH &&
    ) WHERE (profile_id IS NOT NULL);
ALTER TABLE inventory.resource_assignment_history
    ADD CONSTRAINT ex_rah_full_account_time EXCLUDE USING gist (
        account_id WITH =,
        tstzrange(assigned_at, released_at, '[)') WITH &&
    ) WHERE (account_id IS NOT NULL);

CREATE INDEX ix_audit_event_actor_time ON identity.audit_event (actor_user_id, occurred_at);
CREATE INDEX ix_audit_event_entity_time ON identity.audit_event (entity_type, entity_id, occurred_at);
CREATE INDEX ix_audit_event_occurred ON identity.audit_event (occurred_at);
CREATE INDEX ix_seller_customer_customer ON identity.seller_customer (customer_id);
CREATE INDEX ix_platform_status_name ON catalog.platform (status_code, name);
CREATE INDEX ix_product_platform_status ON catalog.product (platform_id, status_code);
CREATE INDEX ix_product_offer_product_status ON catalog.product_offer (product_id, status_code);
CREATE INDEX ix_price_list_role_status ON catalog.price_list (target_role, status_code);
CREATE INDEX ix_price_list_item_lookup ON catalog.price_list_item (price_list_id, product_offer_id, valid_from);
CREATE INDEX ix_account_platform_active ON inventory.account (platform_id, is_active);
CREATE INDEX ix_account_enabled ON inventory.account (platform_id, id) WHERE is_active;
CREATE INDEX ix_profile_account_active ON inventory.profile (account_id, is_active);
CREATE INDEX ix_profile_enabled ON inventory.profile (account_id, id) WHERE is_active;
CREATE INDEX ix_rah_account_current ON inventory.resource_assignment_history (account_id, released_at) WHERE account_id IS NOT NULL;
CREATE INDEX ix_rah_actor_assigned_at ON inventory.resource_assignment_history (performed_by_user_id, assigned_at);
CREATE INDEX ix_orders_buyer_status_created ON sales.orders (buyer_seller_id, status_code, created_at);
CREATE INDEX ix_orders_beneficiary_seller ON sales.orders (beneficiary_seller_id) WHERE beneficiary_seller_id IS NOT NULL;
CREATE INDEX ix_orders_beneficiary_customer ON sales.orders (beneficiary_customer_id) WHERE beneficiary_customer_id IS NOT NULL;
CREATE INDEX ix_order_item_order ON sales.order_item (order_id);
CREATE INDEX ix_order_item_offer ON sales.order_item (product_offer_id);
CREATE INDEX ix_order_item_previous_subscription ON sales.order_item (previous_subscription_id) WHERE previous_subscription_id IS NOT NULL;
CREATE INDEX ix_subscription_order_item ON sales.subscription (order_item_id);
CREATE INDEX ix_subscription_expiration_date ON sales.subscription (expiration_date);
CREATE INDEX ix_wallet_tx_wallet_occurred ON wallet.wallet_transaction (wallet_id, occurred_at);
CREATE INDEX ix_wallet_tx_order ON wallet.wallet_transaction (order_id) WHERE order_id IS NOT NULL;
CREATE INDEX ix_wallet_tx_actor_occurred ON wallet.wallet_transaction (originated_by_user_id, occurred_at);

--rollback DROP INDEX IF EXISTS wallet.ix_wallet_tx_actor_occurred;
--rollback DROP INDEX IF EXISTS wallet.ix_wallet_tx_order;
--rollback DROP INDEX IF EXISTS wallet.ix_wallet_tx_wallet_occurred;
--rollback DROP INDEX IF EXISTS sales.ix_subscription_expiration_date;
--rollback DROP INDEX IF EXISTS sales.ix_subscription_order_item;
--rollback DROP INDEX IF EXISTS sales.ix_order_item_previous_subscription;
--rollback DROP INDEX IF EXISTS sales.ix_order_item_offer;
--rollback DROP INDEX IF EXISTS sales.ix_order_item_order;
--rollback DROP INDEX IF EXISTS sales.ix_orders_beneficiary_customer;
--rollback DROP INDEX IF EXISTS sales.ix_orders_beneficiary_seller;
--rollback DROP INDEX IF EXISTS sales.ix_orders_buyer_status_created;
--rollback DROP INDEX IF EXISTS inventory.ix_rah_actor_assigned_at;
--rollback DROP INDEX IF EXISTS inventory.ix_rah_account_current;
--rollback DROP INDEX IF EXISTS inventory.ix_profile_enabled;
--rollback DROP INDEX IF EXISTS inventory.ix_profile_account_active;
--rollback DROP INDEX IF EXISTS inventory.ix_account_enabled;
--rollback DROP INDEX IF EXISTS inventory.ix_account_platform_active;
--rollback DROP INDEX IF EXISTS catalog.ix_price_list_item_lookup;
--rollback DROP INDEX IF EXISTS catalog.ix_price_list_role_status;
--rollback DROP INDEX IF EXISTS catalog.ix_product_offer_product_status;
--rollback DROP INDEX IF EXISTS catalog.ix_product_platform_status;
--rollback DROP INDEX IF EXISTS catalog.ix_platform_status_name;
--rollback DROP INDEX IF EXISTS identity.ix_seller_customer_customer;
--rollback DROP INDEX IF EXISTS identity.ix_audit_event_occurred;
--rollback DROP INDEX IF EXISTS identity.ix_audit_event_entity_time;
--rollback DROP INDEX IF EXISTS identity.ix_audit_event_actor_time;
