--liquibase formatted sql
--changeset yeiapp:003-identity-tables
CREATE TABLE identity.app_user (
    id uuid NOT NULL,
    name varchar(200) NOT NULL,
    email varchar(320) NOT NULL,
    phone varchar(50),
    password_hash text NOT NULL,
    status_code varchar(30) NOT NULL DEFAULT 'ACTIVE',
    created_at timestamptz NOT NULL DEFAULT current_timestamp,
    updated_at timestamptz NOT NULL DEFAULT current_timestamp,
    CONSTRAINT pk_app_user PRIMARY KEY (id),
    CONSTRAINT ck_app_user_status CHECK (status_code IN ('ACTIVE', 'INACTIVE'))
);

CREATE TABLE identity.user_role (
    user_id uuid NOT NULL,
    role_code varchar(20) NOT NULL,
    CONSTRAINT pk_user_role PRIMARY KEY (user_id, role_code),
    CONSTRAINT fk_user_role_user FOREIGN KEY (user_id) REFERENCES identity.app_user(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_user_role_code CHECK (role_code IN ('ADMIN', 'SELLER', 'CUSTOMER'))
);

CREATE TABLE identity.audit_event (
    id uuid NOT NULL,
    actor_type varchar(10) NOT NULL,
    actor_user_id uuid,
    action_code varchar(80) NOT NULL,
    entity_type varchar(80) NOT NULL,
    entity_id uuid NOT NULL,
    occurred_at timestamptz NOT NULL DEFAULT current_timestamp,
    changed_fields jsonb,
    details jsonb,
    request_id varchar(100),
    CONSTRAINT pk_audit_event PRIMARY KEY (id),
    CONSTRAINT fk_audit_event_actor FOREIGN KEY (actor_user_id) REFERENCES identity.app_user(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_audit_event_actor CHECK ((actor_type = 'USER' AND actor_user_id IS NOT NULL) OR (actor_type = 'SYSTEM' AND actor_user_id IS NULL)),
    CONSTRAINT ck_audit_event_type CHECK (actor_type IN ('USER', 'SYSTEM')),
    CONSTRAINT ck_audit_event_no_secrets CHECK (
      changed_fields IS NULL OR NOT jsonb_exists_any(changed_fields, ARRAY['password', 'password_hash', 'secret_payload', 'token', 'access_token', 'refresh_token'])
    ),
    CONSTRAINT ck_audit_event_details_no_secrets CHECK (
      details IS NULL OR NOT jsonb_exists_any(details, ARRAY['password', 'password_hash', 'secret_payload', 'token', 'access_token', 'refresh_token'])
    )
);

CREATE TABLE identity.seller (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    status_code varchar(30) NOT NULL DEFAULT 'ACTIVE',
    created_at timestamptz NOT NULL DEFAULT current_timestamp,
    updated_at timestamptz NOT NULL DEFAULT current_timestamp,
    CONSTRAINT pk_seller PRIMARY KEY (id),
    CONSTRAINT uq_seller_user UNIQUE (user_id),
    CONSTRAINT fk_seller_user FOREIGN KEY (user_id) REFERENCES identity.app_user(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_seller_status CHECK (status_code IN ('ACTIVE', 'INACTIVE'))
);

CREATE TABLE identity.customer (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    status_code varchar(30) NOT NULL DEFAULT 'ACTIVE',
    created_at timestamptz NOT NULL DEFAULT current_timestamp,
    updated_at timestamptz NOT NULL DEFAULT current_timestamp,
    CONSTRAINT pk_customer PRIMARY KEY (id),
    CONSTRAINT uq_customer_user UNIQUE (user_id),
    CONSTRAINT fk_customer_user FOREIGN KEY (user_id) REFERENCES identity.app_user(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_customer_status CHECK (status_code IN ('ACTIVE', 'INACTIVE'))
);

CREATE TABLE identity.seller_customer (
    id uuid NOT NULL,
    seller_id uuid NOT NULL,
    customer_id uuid NOT NULL,
    status_code varchar(20) NOT NULL DEFAULT 'ACTIVE',
    created_at timestamptz NOT NULL DEFAULT current_timestamp,
    updated_at timestamptz NOT NULL DEFAULT current_timestamp,
    CONSTRAINT pk_seller_customer PRIMARY KEY (id),
    CONSTRAINT uq_seller_customer_pair UNIQUE (seller_id, customer_id),
    CONSTRAINT fk_seller_customer_seller FOREIGN KEY (seller_id) REFERENCES identity.seller(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_seller_customer_customer FOREIGN KEY (customer_id) REFERENCES identity.customer(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_seller_customer_status CHECK (status_code IN ('ACTIVE', 'INACTIVE'))
);

--rollback DROP TABLE IF EXISTS identity.seller_customer;
--rollback DROP TABLE IF EXISTS identity.customer;
--rollback DROP TABLE IF EXISTS identity.seller;
--rollback DROP TABLE IF EXISTS identity.audit_event;
--rollback DROP TABLE IF EXISTS identity.user_role;
--rollback DROP TABLE IF EXISTS identity.app_user;
