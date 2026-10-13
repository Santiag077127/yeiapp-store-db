--liquibase formatted sql
--changeset yeiapp:007-inventory-availability splitStatements:false
CREATE VIEW inventory.account_availability AS
SELECT
    a.id AS account_id,
    CASE
        WHEN NOT a.is_active OR a.login_identifier IS NULL OR a.secret_payload IS NULL THEN 'INACTIVE'
        WHEN EXISTS (
            SELECT 1 FROM inventory.resource_assignment_history rah
            WHERE rah.account_id = a.id AND rah.released_at IS NULL
        ) THEN 'FULLY_ASSIGNED'
        WHEN EXISTS (
            SELECT 1 FROM inventory.profile p
            WHERE p.account_id = a.id AND p.is_active
              AND NOT EXISTS (
                  SELECT 1 FROM inventory.resource_assignment_history rah
                  WHERE rah.profile_id = p.id AND rah.released_at IS NULL
              )
        ) THEN CASE WHEN EXISTS (
            SELECT 1 FROM inventory.resource_assignment_history rah
            JOIN inventory.profile p ON p.id = rah.profile_id
            WHERE p.account_id = a.id AND rah.released_at IS NULL
        ) THEN 'PARTIALLY_ASSIGNED' ELSE 'AVAILABLE' END
        ELSE 'FULLY_ASSIGNED'
    END AS availability_code
FROM inventory.account a;

CREATE VIEW inventory.profile_availability AS
SELECT
    p.id AS profile_id,
    CASE
        WHEN NOT p.is_active OR NOT a.is_active OR a.login_identifier IS NULL OR a.secret_payload IS NULL THEN 'INACTIVE'
        WHEN EXISTS (
            SELECT 1 FROM inventory.resource_assignment_history rah
            WHERE rah.account_id = a.id AND rah.released_at IS NULL
        ) THEN 'BLOCKED_BY_FULL_ACCOUNT'
        WHEN EXISTS (
            SELECT 1 FROM inventory.resource_assignment_history rah
            WHERE rah.profile_id = p.id AND rah.released_at IS NULL
        ) THEN 'ASSIGNED'
        ELSE 'AVAILABLE'
    END AS availability_code
FROM inventory.profile p
JOIN inventory.account a ON a.id = p.account_id;

--rollback DROP VIEW IF EXISTS inventory.profile_availability;
--rollback DROP VIEW IF EXISTS inventory.account_availability;
