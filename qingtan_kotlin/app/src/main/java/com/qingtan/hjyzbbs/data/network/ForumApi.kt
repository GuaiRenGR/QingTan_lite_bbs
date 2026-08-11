package com.qingtan.hjyzbbs.data.network

import android.content.Context
import com.qingtan.hjyzbbs.core.AppConfig
import com.qingtan.hjyzbbs.data.model.ApiResult
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

class ForumApi(context: Context) {
    private val preferences = context.getSharedPreferences("qingtan_auth", Context.MODE_PRIVATE)

    val cachedUser: JSONObject?
        get() = preferences.getString("user", null)?.let {
            runCatching { JSONObject(it) }.getOrNull()
        }

    val hasToken: Boolean
        get() = !preferences.getString("token", null).isNullOrBlank()

    fun feed(channel: String, page: Int, excluded: List<Int>) = request(
        route = "threads/recommend",
        parameters = mapOf(
            "page" to page,
            "page_size" to AppConfig.PAGE_SIZE,
            "channel" to channel,
            "exclude_ids" to excluded,
        ),
    )

    fun detail(id: Int) = request("threads/detail", parameters = mapOf("id" to id))
    fun me() = request("user/me")
    fun login(account: String, password: String) = request(
        route = "auth/login",
        post = true,
        parameters = mapOf("account" to account, "password" to password),
    )
    fun logout() = request("auth/logout", post = true)

    fun saveSession(data: JSONObject) {
        preferences.edit()
            .putString("token", data.optString("access_token"))
            .putString("user", data.optJSONObject("user")?.toString())
            .apply()
    }

    fun saveUser(user: JSONObject) {
        preferences.edit().putString("user", user.toString()).apply()
    }

    fun clearSession() {
        preferences.edit().clear().apply()
    }

    private fun request(
        route: String,
        post: Boolean = false,
        parameters: Map<String, Any> = emptyMap(),
    ): ApiResult = try {
        val fields = encodeParameters(parameters)
        val suffix = if (!post && fields.isNotBlank()) "&$fields" else ""
        val connection = URL("${AppConfig.API_ENTRY}?route=${encode(route)}$suffix")
            .openConnection() as HttpURLConnection

        connection.requestMethod = if (post) "POST" else "GET"
        connection.connectTimeout = 5_000
        connection.readTimeout = 10_000
        connection.setRequestProperty("Accept", "application/json")
        connection.setRequestProperty("X-Client", "kotlin")
        preferences.getString("token", null)
            ?.takeIf { it.isNotBlank() }
            ?.let { connection.setRequestProperty("Authorization", "Bearer $it") }

        if (post) {
            connection.doOutput = true
            connection.setRequestProperty(
                "Content-Type",
                "application/x-www-form-urlencoded; charset=UTF-8",
            )
            connection.outputStream.use { it.write(fields.toByteArray()) }
        }

        val stream = if (connection.responseCode in 200..399) {
            connection.inputStream
        } else {
            connection.errorStream
        }
        val root = JSONObject(stream?.bufferedReader()?.use { it.readText() } ?: "{}")
        ApiResult(
            data = root.opt("data").takeUnless { it == JSONObject.NULL },
            message = root.optString("message", "请求失败"),
            code = root.optInt("code", connection.responseCode),
        )
    } catch (error: Exception) {
        ApiResult(null, error.message ?: "当前网络不可用", -1)
    }

    private fun encodeParameters(parameters: Map<String, Any>) = parameters.entries
        .flatMap { (key, value) ->
            if (value is Iterable<*>) {
                value.map { "${encode(key)}%5B%5D=${encode(it.toString())}" }
            } else {
                listOf("${encode(key)}=${encode(value.toString())}")
            }
        }
        .joinToString("&")

    private fun encode(value: String) = URLEncoder.encode(value, "UTF-8")
}
