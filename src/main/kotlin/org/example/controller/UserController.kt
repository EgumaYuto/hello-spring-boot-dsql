package org.example.controller

import org.example.repository.UserModel
import org.example.repository.UserRepository
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/user")
class UserController(
    val userRepository: UserRepository
) {

    @GetMapping
    fun index(): List<UserModel> {
        return userRepository.findAll()
    }
}
