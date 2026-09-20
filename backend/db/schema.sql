-- GuardSync — PostgreSQL schema
--
-- The API creates this schema itself on first start (EnsureCreated / Migrate),
-- so running this file is optional. It exists for DBA-provisioned databases and
-- as a readable reference for what the EF Core model produces.
--
--   psql -h localhost -U guardsync -d guardsync -f schema.sql

BEGIN;

CREATE TABLE IF NOT EXISTS users (
    id                      uuid PRIMARY KEY,
    email                   varchar(256) NOT NULL,
    password_hash           text         NOT NULL,
    display_name            varchar(120) NOT NULL DEFAULT '',
    role                    varchar(20)  NOT NULL DEFAULT 'guard',
    is_active               boolean      NOT NULL DEFAULT TRUE,
    reset_token             varchar(200),
    reset_token_expires_at  timestamptz,
    created_at              timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT ck_users_role CHECK (role IN ('guard', 'admin'))
);

CREATE UNIQUE INDEX IF NOT EXISTS ix_users_email ON users (email);

CREATE TABLE IF NOT EXISTS employees (
    id                     uuid PRIMARY KEY,
    employee_number        varchar(60),
    full_name              varchar(200) NOT NULL,
    department             varchar(120) NOT NULL DEFAULT '',
    photo_url              text,
    has_housing            boolean      NOT NULL DEFAULT FALSE,
    has_travel_permission  boolean      NOT NULL DEFAULT FALSE,
    phone                  varchar(40),
    position               varchar(120),
    qr_code                varchar(200),
    is_active              boolean      NOT NULL DEFAULT TRUE,
    created_at             timestamptz  NOT NULL DEFAULT now(),
    updated_at             timestamptz  NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS ix_employees_employee_number
    ON employees (employee_number) WHERE employee_number IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_employees_is_active ON employees (is_active);

CREATE TABLE IF NOT EXISTS attendance_records (
    id              uuid PRIMARY KEY,
    employee_id     uuid        NOT NULL REFERENCES employees (id) ON DELETE CASCADE,
    date            date        NOT NULL,
    check_in_time   time,
    check_out_time  time,
    status          varchar(30) NOT NULL DEFAULT 'pending',
    notes           text,
    guard_name      varchar(120),
    is_early_leave  boolean     NOT NULL DEFAULT FALSE,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

-- One record per employee per day. Firestore could not express this, which is
-- how duplicate same-day rows used to slip in.
CREATE UNIQUE INDEX IF NOT EXISTS ix_attendance_employee_date
    ON attendance_records (employee_id, date);
CREATE INDEX IF NOT EXISTS ix_attendance_date ON attendance_records (date);

CREATE TABLE IF NOT EXISTS permission_requests (
    id               uuid PRIMARY KEY,
    employee_id      uuid        NOT NULL REFERENCES employees (id) ON DELETE CASCADE,
    permission_type  varchar(40) NOT NULL,
    date             date        NOT NULL,
    start_time       time,
    end_time         time,
    reason           text,
    status           varchar(20) NOT NULL DEFAULT 'approved',
    approved_by      varchar(120),
    notes            text,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_permission_status CHECK (status IN ('pending', 'approved', 'rejected'))
);

CREATE INDEX IF NOT EXISTS ix_permissions_employee_date_type
    ON permission_requests (employee_id, date, permission_type);
CREATE INDEX IF NOT EXISTS ix_permissions_date ON permission_requests (date);

CREATE TABLE IF NOT EXISTS admin_notifications (
    id                uuid PRIMARY KEY,
    type              varchar(60)  NOT NULL,
    employee_id       uuid         NOT NULL,
    employee_name     varchar(200) NOT NULL DEFAULT '',
    message           text         NOT NULL DEFAULT '',
    date              date         NOT NULL,
    early_leave_count integer      NOT NULL DEFAULT 0,
    is_read           boolean      NOT NULL DEFAULT FALSE,
    created_at        timestamptz  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_notifications_is_read ON admin_notifications (is_read);
CREATE INDEX IF NOT EXISTS ix_notifications_employee_type_date
    ON admin_notifications (employee_id, type, date);

COMMIT;
