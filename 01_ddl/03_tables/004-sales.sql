--liquibase formatted sql
--changeset yeiapp:006-sales-tables
CREATE TABLE sales.orders (
    id uuid NOT NULL,
    order_number uuid NOT NULL,
    buyer_seller_id uuid NOT NULL,
    beneficiary_seller_id uuid,
    beneficiary_customer_id uuid,
    buyer_name_snapshot varchar(200) NOT NULL,
    buyer_email_snapshot varchar(320) NOT NULL,
    buyer_phone_snapshot varchar(50),
    beneficiary_name_snapshot varchar(200) NOT NULL,
    beneficiary_email_snapshot varchar(320) NOT NULL,
    beneficiary_phone_snapshot varchar(50),
    currency_code char(3) NOT NULL,
    status_code varchar(30) NOT NULL DEFAULT 'PENDING',
    created_at timestamptz NOT NULL DEFAULT current_timestamp,
    confirmed_at timestamptz,
    CONSTRAINT pk_orders PRIMARY KEY (id),
    CONSTRAINT uq_orders_order_number UNIQUE (order_number),
    CONSTRAINT fk_orders_buyer FOREIGN KEY (buyer_seller_id) REFERENCES identity.seller(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_orders_beneficiary_seller FOREIGN KEY (beneficiary_seller_id) REFERENCES identity.seller(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_orders_beneficiary_pair FOREIGN KEY (buyer_seller_id, beneficiary_customer_id) REFERENCES identity.seller_customer(seller_id, customer_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_orders_beneficiary_xor CHECK ((beneficiary_seller_id IS NOT NULL) <> (beneficiary_customer_id IS NOT NULL)),
    CONSTRAINT ck_orders_beneficiary_seller CHECK (beneficiary_seller_id IS NULL OR beneficiary_seller_id = buyer_seller_id),
    CONSTRAINT ck_orders_currency CHECK (currency_code ~ '^[A-Z]{3}$'),
    CONSTRAINT ck_orders_status CHECK (status_code IN ('PENDING', 'CONFIRMED', 'CANCELLED')),
    CONSTRAINT ck_orders_confirmed_at CHECK ((status_code = 'CONFIRMED' AND confirmed_at IS NOT NULL) OR (status_code IN ('PENDING', 'CANCELLED') AND confirmed_at IS NULL))
);

CREATE TABLE sales.order_item (
    id uuid NOT NULL,
    order_id uuid NOT NULL,
    product_id uuid NOT NULL,
    product_name_snapshot varchar(200) NOT NULL,
    product_offer_id uuid NOT NULL,
    unit_price numeric(19,4) NOT NULL,
    currency_code char(3) NOT NULL,
    service_duration_days integer NOT NULL,
    sale_mode_snapshot varchar(20) NOT NULL,
    quantity integer NOT NULL,
    previous_subscription_id uuid,
    created_at timestamptz NOT NULL DEFAULT current_timestamp,
    updated_at timestamptz NOT NULL DEFAULT current_timestamp,
    CONSTRAINT pk_order_item PRIMARY KEY (id),
    CONSTRAINT fk_order_item_order FOREIGN KEY (order_id) REFERENCES sales.orders(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_order_item_offer_product FOREIGN KEY (product_offer_id, product_id) REFERENCES catalog.product_offer(id, product_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_order_item_price CHECK (unit_price >= 0),
    CONSTRAINT ck_order_item_currency CHECK (currency_code ~ '^[A-Z]{3}$'),
    CONSTRAINT ck_order_item_duration CHECK (service_duration_days > 0),
    CONSTRAINT ck_order_item_mode CHECK (sale_mode_snapshot IN ('PROFILE', 'FULL_ACCOUNT')),
    CONSTRAINT ck_order_item_quantity CHECK (quantity > 0 AND (previous_subscription_id IS NULL OR quantity = 1))
);

CREATE TABLE sales.subscription (
    id uuid NOT NULL,
    order_item_id uuid NOT NULL,
    start_date date NOT NULL,
    expiration_date date NOT NULL,
    previous_subscription_id uuid,
    created_at timestamptz NOT NULL DEFAULT current_timestamp,
    CONSTRAINT pk_subscription PRIMARY KEY (id),
    CONSTRAINT fk_subscription_order_item FOREIGN KEY (order_item_id) REFERENCES sales.order_item(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_subscription_previous FOREIGN KEY (previous_subscription_id) REFERENCES sales.subscription(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_subscription_dates CHECK (expiration_date > start_date),
    CONSTRAINT ck_subscription_not_self CHECK (previous_subscription_id IS NULL OR previous_subscription_id <> id)
);

ALTER TABLE sales.order_item
    ADD CONSTRAINT fk_order_item_previous_subscription
    FOREIGN KEY (previous_subscription_id) REFERENCES sales.subscription(id) ON DELETE RESTRICT ON UPDATE RESTRICT;

--rollback ALTER TABLE sales.order_item DROP CONSTRAINT IF EXISTS fk_order_item_previous_subscription;
--rollback DROP TABLE IF EXISTS sales.subscription;
--rollback DROP TABLE IF EXISTS sales.order_item;
--rollback DROP TABLE IF EXISTS sales.orders;
