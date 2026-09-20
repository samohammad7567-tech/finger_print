# GuardSync API — ASP.NET Core + PostgreSQL

The backend that replaced Firebase Auth and Cloud Firestore. It is a plain
ASP.NET Core Web API on .NET 9, talking to PostgreSQL through EF Core (Npgsql),
with JWT bearer authentication.

## Layout

```
backend/
  GuardSync.Api/
    Program.cs                 # DI, JWT, CORS, snake_case JSON, error envelope
    Entities/                  # AppUser, Employee, AttendanceRecord, PermissionRequest, AdminNotification
    Data/AppDbContext.cs       # mapping, indexes, snake_case column naming
    Data/DbInitializer.cs      # schema creation + admin seed on startup
    Dtos/                      # the exact JSON shapes the Flutter models read
    Controllers/               # auth, employees, attendance, permissions, notifications
    Services/                  # TokenService (JWT), ValueParser (dates/times/ids)
  db/schema.sql                # the same schema as raw SQL (optional / reference)
  docker-compose.yml           # PostgreSQL 16 for local development
```

## Running it

1. Start PostgreSQL:

   ```bash
   cd backend
   docker compose up -d
   ```

   Or point `ConnectionStrings:Postgres` at any existing PostgreSQL instance.

2. Set a signing key. The API refuses to start without one of at least 32
   characters:

   ```bash
   cd GuardSync.Api
   dotnet user-secrets init
   dotnet user-secrets set "Jwt:Key" "a-long-random-value-of-at-least-32-chars"
   ```

   `appsettings.Development.json` ships a placeholder key so `dotnet run` works
   out of the box locally. Never use it anywhere else.

3. Run:

   ```bash
   dotnet run
   ```

   The API listens on `http://0.0.0.0:5080`, creates its schema on first start,
   seeds the admin account from the `Seed:*` settings, and serves Swagger UI at
   `/swagger` in Development.

   Default development admin: `admin@guardsync.local` / `Admin@12345`.
   Change or clear `Seed:*` before deploying.

### Migrations

The project ships no migration files, so `DbInitializer` falls back to
`EnsureCreated()` — enough for development and for a fresh database. For a
production deployment that needs versioned schema changes, generate a migration
once and `DbInitializer` will switch to `Migrate()` automatically:

```bash
dotnet tool install --global dotnet-ef
dotnet ef migrations add InitialCreate
```

`db/schema.sql` is the same schema written by hand, for databases provisioned by
a DBA rather than by the app.

## Conventions

**JSON is snake_case in both directions.** `JsonNamingPolicy.SnakeCaseLower` is
configured globally so the wire format matches the Flutter models field for
field — `employee_id`, `check_in_time`, `is_early_leave` — and the client needs
no mapping layer.

**Dates and times are strings.** Dates are `yyyy-MM-dd`, times are `HH:mm`.
They are stored as real `date` and `time` columns and formatted on the way out,
so range queries happen in the database instead of by string comparison.

**Ids are GUIDs rendered as strings**, which is what the Dart models already
expect for `id`.

**Errors always look the same:**

```json
{ "error": "error_invalid_credentials", "message": "optional detail" }
```

`error` is a stable key, never a translated sentence. The Flutter `ErrorMapper`
turns it straight into a localization key. Adding a new key on the server is
safe: the client falls back to a status-based key for anything it does not know.

## Endpoints

All routes require `Authorization: Bearer <token>` except the auth ones marked
anonymous. Writes under `/api/employees` additionally require the `admin` role.

| Method | Route | Purpose |
| --- | --- | --- |
| POST | `/api/auth/login` | Sign in, returns token + user |
| POST | `/api/auth/register` | Create a guard account |
| GET | `/api/auth/me` | Re-read the current user (role changes) |
| POST | `/api/auth/forgot-password` | Issue a reset token |
| POST | `/api/auth/reset-password` | Consume a reset token |
| GET | `/api/employees?activeOnly=` | List employees |
| GET | `/api/employees/{id}` | One employee |
| POST | `/api/employees` | Create (admin) |
| PATCH | `/api/employees/{id}` | Partial update (admin) |
| DELETE | `/api/employees/{id}` | Delete (admin) |
| GET | `/api/attendance?date=&employee_id=&start=&end=&limit=` | Records, filters combine |
| GET | `/api/attendance/find?employee_id=&date=` | Single record, `204` when none |
| GET | `/api/attendance/early-leaves/count?employee_id=&year_month=` | Monthly early-leave count |
| POST | `/api/attendance` | Create a record |
| PATCH | `/api/attendance/{id}` | Partial update |
| GET | `/api/permissions?date=&employee_id=&start=&end=&status=&limit=` | Permissions |
| GET | `/api/permissions/find?employee_id=&date=&permission_type=` | Single permission, `204` when none |
| GET | `/api/permissions/vacations/count?employee_id=&year_month=` | Approved vacation days that month |
| POST | `/api/permissions` | Create a permission |
| PATCH | `/api/permissions/{id}/status` | Approve / reject |
| GET | `/api/notifications?limit=` | Admin notifications |
| GET | `/api/notifications/unread-count` | Unread badge count |
| GET | `/api/notifications/exists?employee_id=&year_month=&type=` | Was this alert already raised |
| POST | `/api/notifications` | Raise a notification |
| PATCH | `/api/notifications/{id}/read` | Mark one read |
| PATCH | `/api/notifications/read-all` | Mark all read |
| GET | `/health` | Liveness probe |

## What the database enforces that Firestore could not

- **One attendance record per employee per day** — a unique index on
  `(employee_id, date)`. Duplicate same-day rows are now impossible rather than
  merely unlikely.
- **Referential integrity** — attendance records and permission requests are
  foreign-keyed to `employees` and cascade on delete, so removing an employee
  cannot leave orphaned rows.
- **Correct month boundaries** — monthly counts expand `yyyy-MM` to the real
  last day of the month. The Firestore version approximated it as `-31`, which
  quietly over-scanned shorter months.
- **Server-side rules** — the two-vacation-days-per-month limit and the
  one-permission-per-type-per-day rule are checked in the API, not only in the
  app, so they hold no matter which client writes.

## Before deploying

- Set `Jwt:Key` from a secret store, not a config file.
- Set `Cors:AllowedOrigins` — an empty array means "allow any origin", which is
  only appropriate for local development.
- Clear `Seed:AdminPassword` once the real admin account exists.
- Put the API behind TLS. `/auth/login` sends a password and every other call
  sends a bearer token.
- Wire `POST /auth/forgot-password` to a real mail service. It currently logs
  the reset token instead of sending it.
