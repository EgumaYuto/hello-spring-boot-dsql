package org.example

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication

@SpringBootApplication
class MyApplication

fun main(args: Array<String>) {
    @Suppress("SpreadOperator")
    runApplication<MyApplication>(*args)
}
