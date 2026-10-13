--liquibase formatted sql
--changeset yeiapp:005-inventory-tables
CREATE TABLE inventory.account (
    id uuid NOT NULL,
    platform_id uuid NOT NULL,
    login_identifier text,
    secret_payload bytea,
    credential_metadata jsonb,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT current_timestamp,
    updated_at timestamptz NOT NULL DEFAULT current_timestamp,
    CONSTRAINT pk_account PRIMARY KEY (id),
    CONSTRAINT fk_account_platform FOREIGN KEY (platform_id) REFERENCES catalog.platform(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_account_metadata_no_secret CHECK (credential_metadata IS NULL OR NOT jsonb_exists_any(credential_metadata, ARRAY['password', 'secret', 'token', 'access_token', 'refresh_token']))
);

CREATE TABLE inventory.profile (
    id uuid NOT NULL,
    account_id uuid NOT NULL,
    profile_identifier varchar(100) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT current_timestamp,
    updated_at timestamptz NOT NULL DEFAULT current_timestamp,
    CONSTRAINT pk_profile PRIMARY KEY (id),
    CONSTRAINT uq_profile_account_identifier UNIQUE (account_id, profile_identifier),
    CONSTRAINT fk_profile_account FOREIGN KEY (account_id) REFERENCES inventory.account(id) ON DELETE RESTRICT ON UPDATE RESTRICT
);

CREATE TABLE inventory.resource_assignment_history (
    id uuid NOT NULL,
    subscription_id uuid NOT NULL,
    account_id uuid,
    profile_id uuid,
    assigned_at timestamptz NOT NULL,
    released_at timestamptz,
    reason_code varchar(30) NOT NULL,
    sequence integer NOT NULL,
    performed_by_user_id uuid NOT NULL,
    failure_occurred_at timestamptz,
    failure_description text,
    released_by_user_id uuid,
    release_reason_code varchar(30),
    CONSTRAINT pk_resource_assignment_history PRIMARY KEY (id),
    CONSTRAINT fk_rah_subscription FOREIGN KEY (subscription_id) REFERENCES sales.subscription(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_rah_account FOREIGN KEY (account_id) REFERENCES inventory.account(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_rah_profile FOREIGN KEY (profile_id) REFERENCES inventory.profile(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_rah_performed_by FOREIGN KEY (performed_by_user_id) REFERENCES identity.app_user(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_rah_released_by FOREIGN KEY (released_by_user_id) REFERENCES identity.app_user(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT ck_rah_resource_xor CHECK ((account_id IS NOT NULL) <> (profile_id IS NOT NULL)),
    CONSTRAINT ck_rah_released_after_assigned CHECK (released_at IS NULL OR released_at > assigned_at),
    CONSTRAINT ck_rah_reason CHECK (reason_code IN ('INITIAL_ASSIGNMENT', 'WARRANTY_REPLACEMENT')),
    CONSTRAINT ck_rah_sequence CHECK (sequence > 0),
    CONSTRAINT ck_rah_failure CHECK ((reason_code = 'WARRANTY_REPLACEMENT' AND failure_occurred_at IS NOT NULL AND failure_description IS NOT NULL) OR (reason_code = 'INITIAL_ASSIGNMENT' AND failure_occurred_at IS NULL AND failure_description IS NULL)),
    CONSTRAINT ck_rah_release_triplet CHECK ((released_at IS NULL AND released_by_user_id IS NULL AND release_reason_code IS NULL) OR (released_at IS NOT NULL AND released_by_user_id IS NOT NULL AND release_reason_code IS NOT NULL)),
    CONSTRAINT ck_rah_release_reason CHECK (release_reason_code IS NULL OR release_reason_code IN ('WARRANTY_REPLACEMENT', 'RENEWAL_TRANSFER', 'MANUAL_RECONDITIONING'))
);

--rollback DROP TABLE IF EXISTS inventory.resource_assignment_history;
--rollback DROP TABLE IF EXISTS inventory.profile;
--rollback DROP TABLE IF EXISTS inventory.account;
