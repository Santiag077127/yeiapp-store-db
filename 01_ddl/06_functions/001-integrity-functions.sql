--liquibase formatted sql
--changeset yeiapp:008-integrity-functions splitStatements:false endDelimiter:$$
CREATE OR REPLACE FUNCTION identity.enforce_profile_role()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE required_role varchar(20);
BEGIN
    required_role := CASE TG_TABLE_NAME WHEN 'seller' THEN 'SELLER' ELSE 'CUSTOMER' END;
    IF NOT EXISTS (
        SELECT 1 FROM identity.user_role ur WHERE ur.user_id = NEW.user_id AND ur.role_code = required_role
    ) THEN
        RAISE EXCEPTION '% profile requires role %', TG_TABLE_NAME, required_role;
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION identity.protect_profile_role()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.role_code = 'SELLER' AND EXISTS (SELECT 1 FROM identity.seller s WHERE s.user_id = OLD.user_id) THEN
        RAISE EXCEPTION 'cannot remove SELLER role while a Seller profile exists';
    END IF;
    IF OLD.role_code = 'CUSTOMER' AND EXISTS (SELECT 1 FROM identity.customer c WHERE c.user_id = OLD.user_id) THEN
        RAISE EXCEPTION 'cannot remove CUSTOMER role while a Customer profile exists';
    END IF;
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;

CREATE OR REPLACE FUNCTION identity.reject_audit_mutation()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'identity.audit_event is append-only';
END;
$$;

CREATE OR REPLACE FUNCTION catalog.protect_offer_mode()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.sale_mode IS DISTINCT FROM OLD.sale_mode
       AND EXISTS (SELECT 1 FROM sales.order_item oi WHERE oi.product_offer_id = OLD.id) THEN
        RAISE EXCEPTION 'cannot change sale_mode after an OrderItem references the offer';
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION sales.enforce_order_transition()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.status_code = OLD.status_code THEN RETURN NEW; END IF;
    IF OLD.status_code <> 'PENDING' OR NEW.status_code NOT IN ('CONFIRMED', 'CANCELLED') THEN
        RAISE EXCEPTION 'invalid Order state transition: % to %', OLD.status_code, NEW.status_code;
    END IF;
    IF NEW.status_code = 'CONFIRMED' AND NOT EXISTS (SELECT 1 FROM sales.order_item oi WHERE oi.order_id = NEW.id) THEN
        RAISE EXCEPTION 'confirmed Order requires at least one OrderItem';
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION sales.protect_order_item()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE order_status varchar(30); offer_mode varchar(20); affected_order uuid;
BEGIN
    IF TG_OP = 'DELETE' THEN affected_order := OLD.order_id; ELSE affected_order := NEW.order_id; END IF;
    SELECT status_code INTO order_status FROM sales.orders WHERE id = affected_order FOR SHARE;
    IF order_status = 'CONFIRMED' THEN RAISE EXCEPTION 'confirmed Order composition is immutable'; END IF;
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    SELECT sale_mode INTO offer_mode FROM catalog.product_offer WHERE id = NEW.product_offer_id FOR SHARE;
    IF offer_mode IS NULL OR offer_mode <> NEW.sale_mode_snapshot THEN
        RAISE EXCEPTION 'OrderItem sale mode must match ProductOffer';
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION sales.validate_subscription()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE item sales.order_item%ROWTYPE; prior sales.subscription%ROWTYPE;
BEGIN
    IF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION 'Subscription dates and lineage are immutable';
    END IF;
    SELECT * INTO item FROM sales.order_item WHERE id = NEW.order_item_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Subscription OrderItem does not exist'; END IF;
    IF NEW.expiration_date <> NEW.start_date + item.service_duration_days THEN
        RAISE EXCEPTION 'Subscription expiration must match OrderItem duration';
    END IF;
    IF NEW.previous_subscription_id IS DISTINCT FROM item.previous_subscription_id THEN
        RAISE EXCEPTION 'Subscription predecessor must match its OrderItem';
    END IF;
    IF NEW.previous_subscription_id IS NOT NULL THEN
        SELECT * INTO prior FROM sales.subscription WHERE id = NEW.previous_subscription_id;
        IF NOT FOUND OR NEW.start_date < prior.expiration_date THEN
            RAISE EXCEPTION 'renewal must start at or after predecessor expiration';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION inventory.validate_assignment_history()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE item sales.order_item%ROWTYPE; resource_platform uuid; previous_count integer;
BEGIN
    IF TG_OP = 'DELETE' THEN RAISE EXCEPTION 'ResourceAssignmentHistory is append-only'; END IF;
    IF TG_OP = 'UPDATE' THEN
        IF OLD.released_at IS NOT NULL
           OR NEW.subscription_id IS DISTINCT FROM OLD.subscription_id
           OR NEW.account_id IS DISTINCT FROM OLD.account_id
           OR NEW.profile_id IS DISTINCT FROM OLD.profile_id
           OR NEW.assigned_at IS DISTINCT FROM OLD.assigned_at
           OR NEW.reason_code IS DISTINCT FROM OLD.reason_code
           OR NEW.sequence IS DISTINCT FROM OLD.sequence
           OR NEW.performed_by_user_id IS DISTINCT FROM OLD.performed_by_user_id
           OR NEW.failure_occurred_at IS DISTINCT FROM OLD.failure_occurred_at
           OR NEW.failure_description IS DISTINCT FROM OLD.failure_description THEN
            RAISE EXCEPTION 'only one-time release fields may update an assignment history row';
        END IF;
        RETURN NEW;
    END IF;
    SELECT oi.* INTO item FROM sales.subscription s JOIN sales.order_item oi ON oi.id = s.order_item_id WHERE s.id = NEW.subscription_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'assignment requires Subscription context'; END IF;
    IF (item.sale_mode_snapshot = 'FULL_ACCOUNT' AND NEW.account_id IS NULL)
       OR (item.sale_mode_snapshot = 'PROFILE' AND NEW.profile_id IS NULL) THEN
        RAISE EXCEPTION 'assignment resource does not match OrderItem sale mode';
    END IF;
    SELECT CASE WHEN NEW.account_id IS NOT NULL THEN a.platform_id ELSE a.platform_id END INTO resource_platform
      FROM inventory.account a LEFT JOIN inventory.profile p ON p.account_id = a.id
      WHERE (NEW.account_id IS NOT NULL AND a.id = NEW.account_id)
         OR (NEW.profile_id IS NOT NULL AND p.id = NEW.profile_id)
      LIMIT 1;
    IF resource_platform IS NULL OR resource_platform <> (SELECT p.platform_id FROM catalog.product p WHERE p.id = item.product_id) THEN
        RAISE EXCEPTION 'assigned resource Platform does not match Product Platform';
    END IF;
    SELECT count(*) INTO previous_count FROM inventory.resource_assignment_history WHERE subscription_id = NEW.subscription_id;
    IF (NEW.reason_code = 'INITIAL_ASSIGNMENT' AND (NEW.sequence <> 1 OR previous_count <> 0))
       OR (NEW.reason_code = 'WARRANTY_REPLACEMENT' AND (
            NEW.sequence <> previous_count + 1
            OR NOT EXISTS (
                SELECT 1 FROM inventory.resource_assignment_history rah
                WHERE rah.subscription_id = NEW.subscription_id
                  AND rah.sequence = NEW.sequence - 1
                  AND rah.released_at IS NOT NULL
            )
       )) THEN
        RAISE EXCEPTION 'invalid assignment reason or sequence';
    END IF;
    IF NEW.account_id IS NOT NULL AND EXISTS (
        SELECT 1
        FROM inventory.resource_assignment_history rah
        JOIN inventory.profile p ON p.id = rah.profile_id
        WHERE p.account_id = NEW.account_id
          AND tstzrange(rah.assigned_at, rah.released_at, '[)') && tstzrange(NEW.assigned_at, NEW.released_at, '[)')
    ) THEN
        RAISE EXCEPTION 'FULL_ACCOUNT assignment overlaps an assignment of one of its Profiles';
    END IF;
    IF NEW.profile_id IS NOT NULL AND EXISTS (
        SELECT 1
        FROM inventory.resource_assignment_history rah
        JOIN inventory.profile p ON p.account_id = rah.account_id
        WHERE p.id = NEW.profile_id
          AND tstzrange(rah.assigned_at, rah.released_at, '[)') && tstzrange(NEW.assigned_at, NEW.released_at, '[)')
    ) THEN
        RAISE EXCEPTION 'PROFILE assignment overlaps a FULL_ACCOUNT assignment of its Account';
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION wallet.guard_wallet_mutation()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN RAISE EXCEPTION 'Wallet cannot be deleted while its Seller exists'; END IF;
    IF NEW.seller_id IS DISTINCT FROM OLD.seller_id THEN RAISE EXCEPTION 'Wallet Seller is immutable'; END IF;
    IF (NEW.balance IS DISTINCT FROM OLD.balance OR NEW.next_sequence_no IS DISTINCT FROM OLD.next_sequence_no)
       AND pg_trigger_depth() = 1 THEN
        RAISE EXCEPTION 'Wallet balance and sequence can only change through the ledger';
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION wallet.apply_ledger_entry()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE w wallet.wallet%ROWTYPE; original wallet.wallet_transaction%ROWTYPE; buyer uuid; actor_user uuid;
BEGIN
    SELECT * INTO w FROM wallet.wallet WHERE id = NEW.wallet_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Wallet does not exist'; END IF;
    SELECT id INTO actor_user FROM identity.app_user WHERE id = NEW.originated_by_user_id AND status_code = 'ACTIVE';
    IF actor_user IS NULL THEN RAISE EXCEPTION 'WalletTransaction actor must be an active User'; END IF;
    IF NEW.currency_code <> w.currency_code THEN RAISE EXCEPTION 'WalletTransaction currency must match Wallet'; END IF;
    IF NEW.previous_balance <> w.balance THEN RAISE EXCEPTION 'WalletTransaction previous balance does not match Wallet'; END IF;
    IF NEW.type_code IN ('TOP_UP', 'ADJUSTMENT_CREDIT', 'ADJUSTMENT_DEBIT')
       AND NOT EXISTS (SELECT 1 FROM identity.user_role ur WHERE ur.user_id = actor_user AND ur.role_code = 'ADMIN') THEN
        RAISE EXCEPTION 'administrative Wallet movements require ADMIN';
    END IF;
    IF NEW.type_code = 'PURCHASE_DEBIT' THEN
        SELECT buyer_seller_id INTO buyer FROM sales.orders WHERE id = NEW.order_id FOR UPDATE;
        IF buyer IS NULL OR buyer <> w.seller_id
           OR NOT EXISTS (SELECT 1 FROM identity.seller s WHERE s.id = buyer AND s.user_id = actor_user) THEN
            RAISE EXCEPTION 'purchase debit must use the buyer Seller Wallet and actor';
        END IF;
    END IF;
    IF NEW.type_code = 'REVERSAL' THEN
        SELECT * INTO original FROM wallet.wallet_transaction WHERE id = NEW.reversed_wallet_transaction_id;
        IF NOT FOUND OR original.wallet_id <> NEW.wallet_id OR original.currency_code <> NEW.currency_code
           OR original.type_code = 'REVERSAL' OR NEW.amount <> -original.amount THEN
            RAISE EXCEPTION 'invalid WalletTransaction reversal';
        END IF;
    END IF;
    NEW.sequence_no := w.next_sequence_no;
    NEW.resulting_balance := NEW.previous_balance + NEW.amount;
    IF NEW.resulting_balance < 0 THEN RAISE EXCEPTION 'Wallet cannot have negative balance'; END IF;
    UPDATE wallet.wallet SET balance = NEW.resulting_balance, next_sequence_no = w.next_sequence_no + 1, updated_at = current_timestamp WHERE id = w.id;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION wallet.reject_transaction_mutation()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'WalletTransaction is immutable';
END;
$$;

CREATE OR REPLACE FUNCTION identity.assert_seller_wallet()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE affected_seller uuid; wallet_count integer;
BEGIN
    IF TG_TABLE_SCHEMA = 'identity' THEN
        IF TG_OP = 'DELETE' THEN affected_seller := OLD.id; ELSE affected_seller := NEW.id; END IF;
    ELSE
        IF TG_OP = 'DELETE' THEN affected_seller := OLD.seller_id; ELSE affected_seller := NEW.seller_id; END IF;
    END IF;
    IF EXISTS (SELECT 1 FROM identity.seller WHERE id = affected_seller) THEN
        SELECT count(*) INTO wallet_count FROM wallet.wallet WHERE seller_id = affected_seller;
        IF wallet_count <> 1 THEN RAISE EXCEPTION 'each Seller requires exactly one Wallet'; END IF;
    END IF;
    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION inventory.assert_account_profile()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE affected_account uuid; profile_count integer;
BEGIN
    IF TG_TABLE_NAME = 'account' THEN
        IF TG_OP = 'DELETE' THEN affected_account := OLD.id; ELSE affected_account := NEW.id; END IF;
    ELSE
        IF TG_OP = 'DELETE' THEN affected_account := OLD.account_id; ELSE affected_account := NEW.account_id; END IF;
    END IF;
    IF EXISTS (SELECT 1 FROM inventory.account WHERE id = affected_account) THEN
        SELECT count(*) INTO profile_count FROM inventory.profile WHERE account_id = affected_account;
        IF profile_count < 1 THEN RAISE EXCEPTION 'each Account requires at least one Profile'; END IF;
    END IF;
    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION sales.assert_initial_assignment()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE affected_subscription uuid;
BEGIN
    IF TG_TABLE_SCHEMA = 'sales' THEN
        IF TG_OP = 'DELETE' THEN affected_subscription := OLD.id; ELSE affected_subscription := NEW.id; END IF;
    ELSE
        IF TG_OP = 'DELETE' THEN affected_subscription := OLD.subscription_id; ELSE affected_subscription := NEW.subscription_id; END IF;
    END IF;
    IF EXISTS (SELECT 1 FROM sales.subscription WHERE id = affected_subscription)
       AND NOT EXISTS (
           SELECT 1 FROM inventory.resource_assignment_history rah
           WHERE rah.subscription_id = affected_subscription
             AND rah.reason_code = 'INITIAL_ASSIGNMENT' AND rah.sequence = 1
       ) THEN
        RAISE EXCEPTION 'each Subscription requires an INITIAL_ASSIGNMENT with sequence 1';
    END IF;
    RETURN NULL;
END;
$$;
--rollback DROP FUNCTION IF EXISTS wallet.reject_transaction_mutation();
--rollback DROP FUNCTION IF EXISTS wallet.apply_ledger_entry();
--rollback DROP FUNCTION IF EXISTS wallet.guard_wallet_mutation();
--rollback DROP FUNCTION IF EXISTS sales.assert_initial_assignment();
--rollback DROP FUNCTION IF EXISTS inventory.assert_account_profile();
--rollback DROP FUNCTION IF EXISTS identity.assert_seller_wallet();
--rollback DROP FUNCTION IF EXISTS inventory.validate_assignment_history();
--rollback DROP FUNCTION IF EXISTS sales.validate_subscription();
--rollback DROP FUNCTION IF EXISTS sales.protect_order_item();
--rollback DROP FUNCTION IF EXISTS sales.enforce_order_transition();
--rollback DROP FUNCTION IF EXISTS catalog.protect_offer_mode();
--rollback DROP FUNCTION IF EXISTS identity.reject_audit_mutation();
--rollback DROP FUNCTION IF EXISTS identity.protect_profile_role();
--rollback DROP FUNCTION IF EXISTS identity.enforce_profile_role();
