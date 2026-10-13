--liquibase formatted sql
--changeset yeiapp:004-catalog-tables
CREATE TABLE catalog.platform (
    id uuid NOT NULL,
    name varchar(150) NOT NULL,
    status_code varchar(30) NOT NULL DEFAULT 'ACTIVE',
    created_at timestamptz NOT NULL DEFAULT current_timestamp,
    updated_at timestamptz NOT NULL DEFAULT current_timestamp,
    CONSTRAINT pk_platform PRIMARY KEY (id),
    CONSTRAINT ck_platform_status CHECK (status_code IN ('ACTIVE', 'INACTIVE'))
);

CREATE TABLE catalog.product (
    id uuid NOT NULL,
    platform_id uuid NOT NULL,
    name varchar(200) NOT NULL,
    customer_renewable boolean NOT NULL,
    internally_renewable boolean NOT NULL,
    status_code varchar(30) NOT NULL DEFAULT 'ACTIVE',
    created_at timestamptz NOT NULL DEFAULT current_timestamp,
    updated_at timestamptz NOT NULL DEFAULT current_timestamp,
    CONSTRAINT pk_product PRIMARY KEY (id),
    CONSTRAINT fk_product_platform FOREIGN KEY (platform_id) REFERENCES catalog.platform(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_product_status CHECK (status_code IN ('ACTIVE', 'INACTIVE'))
);

CREATE TABLE catalog.product_offer (
    id uuid NOT NULL,
    product_id uuid NOT NULL,
    sale_mode varchar(20) NOT NULL,
    status_code varchar(30) NOT NULL DEFAULT 'ACTIVE',
    created_at timestamptz NOT NULL DEFAULT current_timestamp,
    updated_at timestamptz NOT NULL DEFAULT current_timestamp,
    CONSTRAINT pk_product_offer PRIMARY KEY (id),
    CONSTRAINT uq_product_offer_id_product UNIQUE (id, product_id),
    CONSTRAINT fk_product_offer_product FOREIGN KEY (product_id) REFERENCES catalog.product(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_product_offer_mode CHECK (sale_mode IN ('PROFILE', 'FULL_ACCOUNT')),
    CONSTRAINT ck_product_offer_status CHECK (status_code IN ('ACTIVE', 'INACTIVE'))
);

CREATE TABLE catalog.price_list (
    id uuid NOT NULL,
    name varchar(150) NOT NULL,
    target_role varchar(20) NOT NULL,
    status_code varchar(30) NOT NULL DEFAULT 'ACTIVE',
    created_at timestamptz NOT NULL DEFAULT current_timestamp,
    updated_at timestamptz NOT NULL DEFAULT current_timestamp,
    CONSTRAINT pk_price_list PRIMARY KEY (id),
    CONSTRAINT ck_price_list_role CHECK (target_role IN ('SELLER', 'CUSTOMER')),
    CONSTRAINT ck_price_list_status CHECK (status_code IN ('ACTIVE', 'INACTIVE'))
);

CREATE TABLE catalog.price_list_item (
    id uuid NOT NULL,
    price_list_id uuid NOT NULL,
    product_offer_id uuid NOT NULL,
    amount numeric(19,4) NOT NULL,
    currency_code char(3) NOT NULL,
    valid_from timestamptz NOT NULL,
    valid_to timestamptz,
    priority integer NOT NULL,
    created_at timestamptz NOT NULL DEFAULT current_timestamp,
    updated_at timestamptz NOT NULL DEFAULT current_timestamp,
    CONSTRAINT pk_price_list_item PRIMARY KEY (id),
    CONSTRAINT fk_price_list_item_list FOREIGN KEY (price_list_id) REFERENCES catalog.price_list(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_price_list_item_offer FOREIGN KEY (product_offer_id) REFERENCES catalog.product_offer(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_price_list_item_amount CHECK (amount >= 0),
    CONSTRAINT ck_price_list_item_currency CHECK (currency_code ~ '^[A-Z]{3}$'),
    CONSTRAINT ck_price_list_item_validity CHECK (valid_to IS NULL OR valid_to > valid_from),
    CONSTRAINT ck_price_list_item_priority CHECK (priority > 0),
    CONSTRAINT ex_price_list_item_no_overlap EXCLUDE USING gist (
      price_list_id WITH =,
      product_offer_id WITH =,
      priority WITH =,
      tstzrange(valid_from, valid_to, '[)') WITH &&
    )
);

--rollback DROP TABLE IF EXISTS catalog.price_list_item;
--rollback DROP TABLE IF EXISTS catalog.price_list;
--rollback DROP TABLE IF EXISTS catalog.product_offer;
--rollback DROP TABLE IF EXISTS catalog.product;
--rollback DROP TABLE IF EXISTS catalog.platform;
