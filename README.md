# hello-spring-boot-dsql

An Aurora DSQL flavour of [`hello-spring-boot`](../hello-spring-boot). Same Kotlin +
Spring Boot + jOOQ + Flyway app, but the database is **Amazon Aurora DSQL**
(serverless, PostgreSQL-compatible, IAM-authenticated) and the compute is **AWS
Lambda** behind a Function URL.

## Why Lambda instead of ECS?

Aurora DSQL is serverless (scales to zero), reachable over a **public regional
endpoint with IAM authentication**, so there is **no VPC, NAT gateway, ALB, or
Secrets Manager** to run. That pairs naturally with Lambda:

| | `hello-spring-boot` (Aurora MySQL + ECS) | this project (Aurora DSQL + Lambda) |
|---|---|---|
| DB | Aurora MySQL Serverless v2 (min 0.5 ACU, always billed) | Aurora DSQL (scales to zero) |
| DB auth | username/password in Secrets Manager | **IAM token** (no secret) |
| Networking | VPC + NAT (~$32/mo) + ALB (~$16/mo) | **none** (public endpoint + Function URL) |
| Compute | always-on Fargate task | Lambda (pay per request) |
| Idle cost | meaningful | **~$0** |
| Trade-off | warm, no cold start | JVM cold start (a few seconds) |

For "just trying DSQL", Lambda removes the entire always-on networking layer.
The only cost is a cold start on the first request — fine for a sandbox, and
reducible later with [Lambda SnapStart](https://docs.aws.amazon.com/lambda/latest/dg/snapstart.html).

## How DSQL changes the app

- **PostgreSQL-compatible**, so the driver/jOOQ/Flyway are all PostgreSQL
  (`POSTGRES` dialect), not MySQL.
- **IAM auth** via the official [Aurora DSQL JDBC connector](https://docs.aws.amazon.com/aurora-dsql/latest/userguide/SECTION_program-with-jdbc-connector.html)
  (`software.amazon.dsql:aurora-dsql-jdbc-connector`): the URL scheme is
  `jdbc:aws-dsql:postgresql://…`, the driver is
  `software.amazon.dsql.jdbc.DSQLConnector`, and short-lived auth tokens are
  generated transparently — no password.
- **Connection lifetime**: DSQL closes connections after 60 minutes, so HikariCP
  `max-lifetime` is set to 25 min (see `application.yml`, `dsql` profile).
- **No embedded Tomcat on Lambda**: `aws-serverless-java-container` provides its
  own `ServerlessMVC`, so `spring-boot-starter-tomcat` is excluded from the
  deployment package (a second servlet context leaves the Lambda handler's
  DispatcherServlet uninitialized). Tomcat is added back as `developmentOnly` for
  local `bootRun` — it stays out of the zip via `productionRuntimeClasspath`.
- **Schema differences** (see `db/migration/V1__create_users_table.sql`):
  - UUID primary key (`gen_random_uuid()`) instead of `AUTO_INCREMENT`.
  - One DDL statement per migration (DSQL allows one DDL per transaction).
  - Secondary/`UNIQUE` indexes need `CREATE INDEX ASYNC` — omitted here.
- **Schema migration on DSQL is provisioned out-of-band, not on Lambda boot.**
  Flyway is great locally, but running it inside the Lambda against DSQL stalls:
  creating its own `flyway_schema_history` table involves a secondary index, which
  DSQL only supports via `CREATE INDEX ASYNC` (built and polled on a *separate*
  connection) — that deadlocks/stalls during a cold start. So `spring.flyway.enabled`
  is `false` in the `dsql` profile, and the schema is applied once by the
  **`dsqlInit`** Gradle task (plain JDBC, single DDL, no secondary index). Locally,
  Flyway is still used as normal (`./gradlew flywayMigrate`). The AWS
  [`aurora-dsql-flyway-support`](https://github.com/awslabs/aurora-dsql-tools/tree/main/flyway)
  artifact is still on the classpath for anyone who wants to drive Flyway against
  DSQL from a non-Lambda JVM.

## Local development

Aurora DSQL has no local emulator, so locally we use a plain PostgreSQL container
(it's wire-compatible enough for migrations and jOOQ code generation).

```bash
$ docker compose up -d

# connect to local postgres (password: hellopassword)
$ psql -h 127.0.0.1 -U hellouser -d hellodb

# migration
$ ./gradlew flywayMigrate

# generate jOOQ code from the migrated schema
$ ./gradlew generateHellodbJooq

# run the app locally (normal embedded Tomcat, default profile)
$ ./gradlew bootRun
$ curl http://127.0.0.1:8080/        # -> Hello World!
$ curl http://127.0.0.1:8080/user    # -> []
```

> The generated jOOQ sources under `src/main/generated/jooq/` are committed, so
> the deployable build does not need a database. Re-run `generateHellodbJooq`
> after changing a migration.

## Deploy to AWS (Aurora DSQL + Lambda)

Prerequisites:
- A valid AWS profile. Override with `AWS_PROFILE=...` (default `sandbox`). An
  assume-role profile is fine — `dsqlInit` puts `software.amazon.awssdk:sts` on
  its (local-only) classpath so the SDK can resolve it.
- A region where **Aurora DSQL is available** (default `us-east-1`; override with
  `REGION=...`). DSQL is not yet in every region.
- A JDK to launch Gradle (17+); the build targets Java 21 and Gradle
  auto-provisions a 21 toolchain (the DSQL support artifacts require Java 21).

```bash
$ ./scripts/deploy.sh     # build zip -> terraform apply -> dsqlInit, prints the Function URL
$ ./scripts/teardown.sh   # destroys everything to stop charges
```

After `deploy.sh` (the first request is a cold start):

```bash
$ curl https://<function-url>/        # -> Hello World!
$ curl https://<function-url>/user    # -> [] (reads the Aurora DSQL users table)
```

Seed a sample row to see it round-trip through DSQL:

```bash
$ DSQL_SEED=1 DSQL_JDBC_URL="jdbc:aws-dsql:postgresql://<endpoint>:5432/postgres?user=admin" \
    ./gradlew dsqlInit
$ curl https://<function-url>/user    # -> [{"id":"...","name":"Ada","email":"ada@example.com"}]
```

## What's deployed

A single Terraform stack (`infra/aws/`, local state):

- `aws_dsql_cluster` — the serverless database.
- `aws_lambda_function` (Java 21) running Spring Boot via
  `aws-serverless-java-container`, packaged as a zip (`./gradlew lambdaZip`).
- `aws_lambda_function_url` — public URL (`AuthType: NONE`) for easy `curl`.
- IAM role granting the Lambda `dsql:DbConnectAdmin` on the cluster (no secrets).
- CloudWatch log group.

## Status

Verified end-to-end against a real Aurora DSQL cluster + Lambda Function URL in
`us-east-1`: `GET /` returns `Hello World!`, and `GET /user` reads the DSQL
`users` table (returns `[]`, or the seeded row after `DSQL_SEED=1`). Cold start is
a few seconds; warm requests are sub-second.
