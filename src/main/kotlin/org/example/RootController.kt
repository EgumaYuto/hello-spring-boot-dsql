package org.example

import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
class RootController {

    companion object {
        private const val HELLO_WORLD = "Hello World!"
    }

    @RequestMapping("/")
    fun home() = HELLO_WORLD
}
