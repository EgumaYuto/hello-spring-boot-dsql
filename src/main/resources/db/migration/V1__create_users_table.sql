-- Aurora DSQL notes:
--   * Each migration must contain a single DDL statement (DSQL allows one DDL
--     per transaction); keep one statement per Flyway version file.
--   * No SERIAL / sequences are used here; the primary key is a UUID generated
--     by gen_random_uuid() (built into Postgres 13+ and supported by DSQL).
--   * Secondary / UNIQUE indexes are intentionally omitted: on DSQL they must be
--     created asynchronously, e.g. `CREATE INDEX ASYNC idx_users_email ON users (email);`
--     in a separate migration. Add one if you need it.
CREATE TABLE users (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name       VARCHAR(100) NOT NULL,
    email      VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);
