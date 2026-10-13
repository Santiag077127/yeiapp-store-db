--liquibase formatted sql
--changeset yeiapp:001-btree-gist
CREATE EXTENSION IF NOT EXISTS btree_gist;

--rollback DROP EXTENSION IF EXISTS btree_gist;
