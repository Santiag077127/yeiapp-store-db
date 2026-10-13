--liquibase formatted sql
--changeset yeiapp:009-integrity-triggers splitStatements:false
CREATE TRIGGER trg_seller_requires_role BEFORE INSERT OR UPDATE OF user_id ON identity.seller
FOR EACH ROW EXECUTE FUNCTION identity.enforce_profile_role();
CREATE TRIGGER trg_customer_requires_role BEFORE INSERT OR UPDATE OF user_id ON identity.customer
FOR EACH ROW EXECUTE FUNCTION identity.enforce_profile_role();
CREATE TRIGGER trg_user_role_protect_profile BEFORE DELETE OR UPDATE OF role_code ON identity.user_role
FOR EACH ROW EXECUTE FUNCTION identity.protect_profile_role();
CREATE TRIGGER trg_audit_event_immutable BEFORE UPDATE OR DELETE ON identity.audit_event
FOR EACH ROW EXECUTE FUNCTION identity.reject_audit_mutation();
CREATE TRIGGER trg_product_offer_protect_mode BEFORE UPDATE OF sale_mode ON catalog.product_offer
FOR EACH ROW EXECUTE FUNCTION catalog.protect_offer_mode();
CREATE TRIGGER trg_orders_transition BEFORE UPDATE OF status_code ON sales.orders
FOR EACH ROW EXECUTE FUNCTION sales.enforce_order_transition();
CREATE TRIGGER trg_order_item_protect BEFORE INSERT OR UPDATE OR DELETE ON sales.order_item
FOR EACH ROW EXECUTE FUNCTION sales.protect_order_item();
CREATE TRIGGER trg_subscription_validate BEFORE INSERT OR UPDATE OF order_item_id, start_date, expiration_date, previous_subscription_id ON sales.subscription
FOR EACH ROW EXECUTE FUNCTION sales.validate_subscription();
CREATE TRIGGER trg_rah_validate BEFORE INSERT OR UPDATE OR DELETE ON inventory.resource_assignment_history
FOR EACH ROW EXECUTE FUNCTION inventory.validate_assignment_history();
CREATE TRIGGER trg_wallet_guard BEFORE UPDATE OR DELETE ON wallet.wallet
FOR EACH ROW EXECUTE FUNCTION wallet.guard_wallet_mutation();
CREATE TRIGGER trg_wallet_transaction_apply BEFORE INSERT ON wallet.wallet_transaction
FOR EACH ROW EXECUTE FUNCTION wallet.apply_ledger_entry();
CREATE TRIGGER trg_wallet_transaction_immutable BEFORE UPDATE OR DELETE ON wallet.wallet_transaction
FOR EACH ROW EXECUTE FUNCTION wallet.reject_transaction_mutation();

CREATE CONSTRAINT TRIGGER ct_seller_requires_wallet
AFTER INSERT OR UPDATE OR DELETE ON identity.seller DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION identity.assert_seller_wallet();
CREATE CONSTRAINT TRIGGER ct_wallet_requires_seller_pair
AFTER INSERT OR UPDATE OR DELETE ON wallet.wallet DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION identity.assert_seller_wallet();
CREATE CONSTRAINT TRIGGER ct_account_requires_profile
AFTER INSERT OR UPDATE OR DELETE ON inventory.account DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION inventory.assert_account_profile();
CREATE CONSTRAINT TRIGGER ct_profile_preserves_account_minimum
AFTER INSERT OR UPDATE OR DELETE ON inventory.profile DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION inventory.assert_account_profile();
CREATE CONSTRAINT TRIGGER ct_subscription_requires_initial_assignment
AFTER INSERT OR UPDATE OR DELETE ON sales.subscription DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION sales.assert_initial_assignment();
CREATE CONSTRAINT TRIGGER ct_assignment_preserves_subscription_initial
AFTER INSERT OR UPDATE OR DELETE ON inventory.resource_assignment_history DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION sales.assert_initial_assignment();

--rollback DROP TRIGGER IF EXISTS ct_assignment_preserves_subscription_initial ON inventory.resource_assignment_history;
--rollback DROP TRIGGER IF EXISTS ct_subscription_requires_initial_assignment ON sales.subscription;
--rollback DROP TRIGGER IF EXISTS ct_profile_preserves_account_minimum ON inventory.profile;
--rollback DROP TRIGGER IF EXISTS ct_account_requires_profile ON inventory.account;
--rollback DROP TRIGGER IF EXISTS ct_wallet_requires_seller_pair ON wallet.wallet;
--rollback DROP TRIGGER IF EXISTS ct_seller_requires_wallet ON identity.seller;
--rollback DROP TRIGGER IF EXISTS trg_wallet_transaction_immutable ON wallet.wallet_transaction;
--rollback DROP TRIGGER IF EXISTS trg_wallet_transaction_apply ON wallet.wallet_transaction;
--rollback DROP TRIGGER IF EXISTS trg_wallet_guard ON wallet.wallet;
--rollback DROP TRIGGER IF EXISTS trg_rah_validate ON inventory.resource_assignment_history;
--rollback DROP TRIGGER IF EXISTS trg_subscription_validate ON sales.subscription;
--rollback DROP TRIGGER IF EXISTS trg_order_item_protect ON sales.order_item;
--rollback DROP TRIGGER IF EXISTS trg_orders_transition ON sales.orders;
--rollback DROP TRIGGER IF EXISTS trg_product_offer_protect_mode ON catalog.product_offer;
--rollback DROP TRIGGER IF EXISTS trg_audit_event_immutable ON identity.audit_event;
--rollback DROP TRIGGER IF EXISTS trg_user_role_protect_profile ON identity.user_role;
--rollback DROP TRIGGER IF EXISTS trg_customer_requires_role ON identity.customer;
--rollback DROP TRIGGER IF EXISTS trg_seller_requires_role ON identity.seller;
