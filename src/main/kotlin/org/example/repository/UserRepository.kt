package org.example.repository

import jooq.generated.hellodb.tables.Users.USERS
import org.jooq.DSLContext
import org.springframework.stereotype.Repository

@Repository
class UserRepository(
    private val dslContext: DSLContext
) {

    fun findAll(): List<UserModel> {
        return this.dslContext.select().from(USERS).fetch().map {
            UserModel(
                id = it.getValue(USERS.ID).toString(),
                name = it.getValue(USERS.NAME),
                email = it.getValue(USERS.EMAIL)
            )
        }
    }
}
