--liquibase formatted sql
--changeset yeiapp:007-wallet-tables
CREATE TABLE wallet.wallet (
    id uuid NOT NULL,
    seller_id uuid NOT NULL,
    balance numeric(19,4) NOT NULL DEFAULT 0,
    currency_code char(3) NOT NULL,
    next_sequence_no bigint NOT NULL DEFAULT 1,
    created_at timestamptz NOT NULL DEFAULT current_timestamp,
    updated_at timestamptz NOT NULL DEFAULT current_timestamp,
    CONSTRAINT pk_wallet PRIMARY KEY (id),
    CONSTRAINT uq_wallet_seller UNIQUE (seller_id),
    CONSTRAINT fk_wallet_seller FOREIGN KEY (seller_id) REFERENCES identity.seller(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_wallet_balance CHECK (balance >= 0),
    CONSTRAINT ck_wallet_currency CHECK (currency_code ~ '^[A-Z]{3}$'),
    CONSTRAINT ck_wallet_next_sequence CHECK (next_sequence_no > 0)
);

CREATE TABLE wallet.wallet_transaction (
    id uuid NOT NULL,
    wallet_id uuid NOT NULL,
    sequence_no bigint NOT NULL DEFAULT 0,
    order_id uuid,
    reversed_wallet_transaction_id uuid,
    type_code varchar(30) NOT NULL,
    amount numeric(19,4) NOT NULL,
    previous_balance numeric(19,4) NOT NULL,
    resulting_balance numeric(19,4) NOT NULL DEFAULT 0,
    currency_code char(3) NOT NULL,
    reference varchar(200),
    originated_by_user_id uuid NOT NULL,
    occurred_at timestamptz NOT NULL DEFAULT current_timestamp,
    CONSTRAINT pk_wallet_transaction PRIMARY KEY (id),
    CONSTRAINT fk_wallet_transaction_wallet FOREIGN KEY (wallet_id) REFERENCES wallet.wallet(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_wallet_transaction_order FOREIGN KEY (order_id) REFERENCES sales.orders(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_wallet_transaction_reversed FOREIGN KEY (reversed_wallet_transaction_id) REFERENCES wallet.wallet_transaction(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_wallet_transaction_actor FOREIGN KEY (originated_by_user_id) REFERENCES identity.app_user(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_wallet_transaction_type CHECK (type_code IN ('TOP_UP', 'PURCHASE_DEBIT', 'ADJUSTMENT_CREDIT', 'ADJUSTMENT_DEBIT', 'REVERSAL')),
    CONSTRAINT ck_wallet_transaction_amount CHECK (amount <> 0 AND ((type_code IN ('TOP_UP', 'ADJUSTMENT_CREDIT') AND amount > 0) OR (type_code IN ('PURCHASE_DEBIT', 'ADJUSTMENT_DEBIT') AND amount < 0) OR type_code = 'REVERSAL')),
    CONSTRAINT ck_wallet_transaction_order CHECK ((type_code = 'PURCHASE_DEBIT' AND order_id IS NOT NULL) OR (type_code <> 'PURCHASE_DEBIT' AND order_id IS NULL)),
    CONSTRAINT ck_wallet_transaction_reversal CHECK ((type_code = 'REVERSAL' AND reversed_wallet_transaction_id IS NOT NULL) OR (type_code <> 'REVERSAL' AND reversed_wallet_transaction_id IS NULL)),
    CONSTRAINT ck_wallet_transaction_currency CHECK (currency_code ~ '^[A-Z]{3}$'),
    CONSTRAINT ck_wallet_transaction_balances CHECK (previous_balance >= 0 AND resulting_balance >= 0 AND resulting_balance = previous_balance + amount),
    CONSTRAINT ck_wallet_transaction_sequence CHECK (sequence_no > 0)
);

--rollback DROP TABLE IF EXISTS wallet.wallet_transaction;
--rollback DROP TABLE IF EXISTS wallet.wallet;
