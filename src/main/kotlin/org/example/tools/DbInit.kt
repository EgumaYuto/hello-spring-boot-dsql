package org.example.tools

import java.sql.DriverManager

/**
 * One-off schema provisioning for Aurora DSQL, run via `./gradlew dsqlInit`.
 *
 * Flyway is not used against DSQL inside the Lambda (its schema-history table needs
 * a secondary index, which DSQL only supports via async index creation and which
 * stalls during a cold start). This runner instead applies the schema with plain
 * JDBC through the Aurora DSQL JDBC connector, which generates the IAM auth token
 * from the ambient AWS credentials (e.g. AWS_PROFILE).
 *
 * Connection details come from the DSQL_JDBC_URL env var, e.g.
 *   jdbc:aws-dsql:postgresql://<cluster-id>.dsql.us-east-1.on.aws:5432/postgres?user=admin
 *
 * It mirrors src/main/resources/db/migration/V1__create_users_table.sql but as a
 * single, idempotent DDL with no secondary index (DSQL-friendly).
 */
fun main() {
    val url = System.getenv("DSQL_JDBC_URL")
        ?: error("DSQL_JDBC_URL env var is required, e.g. jdbc:aws-dsql:postgresql://<ep>:5432/postgres?user=admin")

    val ddl = """
        CREATE TABLE IF NOT EXISTS users (
            id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            name       VARCHAR(100) NOT NULL,
            email      VARCHAR(255) NOT NULL,
            created_at TIMESTAMPTZ DEFAULT now()
        )
    """.trimIndent()

    println("Connecting to: ${url.substringBefore('?')}")
    DriverManager.getConnection(url).use { conn ->
        conn.createStatement().use { it.execute(ddl) }
        println("OK: users table is present.")

        // Optional: insert one sample row when DSQL_SEED=1 (handy for the demo).
        if (System.getenv("DSQL_SEED") == "1") {
            conn.prepareStatement("INSERT INTO users (name, email) VALUES (?, ?)").use { ps ->
                ps.setString(1, "Ada")
                ps.setString(2, "ada@example.com")
                ps.executeUpdate()
            }
            println("OK: seeded sample user (Ada).")
        }
    }
}
