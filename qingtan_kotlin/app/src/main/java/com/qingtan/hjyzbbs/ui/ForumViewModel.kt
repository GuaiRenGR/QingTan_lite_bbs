package com.qingtan.hjyzbbs.ui

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.qingtan.hjyzbbs.data.model.Author
import com.qingtan.hjyzbbs.data.model.Comment
import com.qingtan.hjyzbbs.data.model.FeedState
import com.qingtan.hjyzbbs.data.model.FeedThread
import com.qingtan.hjyzbbs.data.model.ThreadDetail
import com.qingtan.hjyzbbs.data.network.ForumApi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

class ForumViewModel(application: Application) : AndroidViewModel(application) {
    private val api = ForumApi(application.applicationContext)

    var feeds by mutableStateOf(mapOf<String, FeedState>())
        private set
    var loggedIn by mutableStateOf(api.hasToken)
        private set
    var user by mutableStateOf(api.cachedUser)
        private set
    var authLoading by mutableStateOf(false)
        private set

    init {
        listOf("recommend", "hot", "digest", "latest").forEach(::refresh)
        if (loggedIn) validateSession()
    }

    fun refresh(channel: String) = load(channel, page = 1, replace = true)

    fun loadMore(channel: String) {
        val state = feeds[channel] ?: FeedState()
        if (!state.loading && state.hasMore) {
            load(channel, page = state.page + 1, replace = false)
        }
    }

    private fun load(channel: String, page: Int, replace: Boolean) {
        val current = feeds[channel] ?: FeedState()
        feeds = feeds + (channel to current.copy(loading = true, error = null))
        viewModelScope.launch(Dispatchers.IO) {
            val excluded = if (replace) emptyList() else current.items.map { it.id }
            val result = api.feed(channel, page, excluded)
            withContext(Dispatchers.Main) {
                val data = result.data as? JSONObject
                val list = data?.optJSONArray("list")
                if (result.code == 0 && list != null) {
                    val parsed = (0 until list.length()).map { parseFeed(list.getJSONObject(it)) }
                    val merged = if (replace) parsed else (current.items + parsed).distinctBy { it.id }
                    feeds = feeds + (
                        channel to FeedState(
                            items = merged,
                            page = page,
                            hasMore = data.optBoolean("has_more"),
                        )
                    )
                } else {
                    feeds = feeds + (
                        channel to current.copy(loading = false, error = result.message)
                    )
                }
            }
        }
    }

    suspend fun fetchDetail(id: Int): Result<ThreadDetail> = withContext(Dispatchers.IO) {
        val result = api.detail(id)
        val root = result.data as? JSONObject
        if (result.code != 0 || root == null) {
            Result.failure(Exception(result.message))
        } else {
            runCatching { parseDetail(root) }
        }
    }

    fun login(account: String, password: String, complete: (String?) -> Unit) {
        authLoading = true
        viewModelScope.launch(Dispatchers.IO) {
            val result = api.login(account, password)
            withContext(Dispatchers.Main) {
                authLoading = false
                val data = result.data as? JSONObject
                if (result.code == 0 && data != null && data.optString("access_token").isNotBlank()) {
                    api.saveSession(data)
                    user = data.optJSONObject("user")
                    loggedIn = true
                    complete(null)
                } else {
                    complete(result.message)
                }
            }
        }
    }

    fun logout() {
        viewModelScope.launch(Dispatchers.IO) {
            api.logout()
            api.clearSession()
            withContext(Dispatchers.Main) {
                loggedIn = false
                user = null
            }
        }
    }

    private fun validateSession() {
        viewModelScope.launch(Dispatchers.IO) {
            val result = api.me()
            withContext(Dispatchers.Main) {
                if (result.code == 0 && result.data is JSONObject) {
                    user = result.data
                    api.saveUser(result.data)
                } else if (result.code == 401 || result.code == 403) {
                    api.clearSession()
                    loggedIn = false
                    user = null
                }
            }
        }
    }

    private fun parseFeed(data: JSONObject) = FeedThread(
        id = data.optInt("id"),
        title = data.optString("title").ifBlank { data.optString("summary") },
        summary = data.optString("summary"),
        cover = data.optString("cover"),
        coverWidth = data.optInt("cover_width"),
        coverHeight = data.optInt("cover_height"),
        likeCount = data.optInt("like_count"),
        replyCount = data.optInt("reply_count"),
        isTop = data.optInt("is_top") == 1,
        isDigest = data.optInt("is_digest") == 1,
        authorName = data.optString("author_name", "用户"),
        authorAvatar = data.optString("author_avatar"),
    )

    private fun parseDetail(root: JSONObject): ThreadDetail {
        val thread = root.getJSONObject("thread")
        val author = thread.optJSONObject("author") ?: JSONObject()
        val images = thread.optJSONArray("images") ?: JSONArray()
        val posts = root.optJSONArray("posts") ?: JSONArray()
        return ThreadDetail(
            title = thread.optString("title"),
            content = thread.optString("content"),
            images = (0 until images.length()).map { images.optString(it) }.filter { it.isNotBlank() },
            views = thread.optInt("view_count"),
            replies = thread.optInt("reply_count"),
            likes = thread.optInt("like_count"),
            createdAt = thread.optString("created_at"),
            author = Author(author.optString("nickname", "用户"), author.optString("avatar")),
            comments = (0 until posts.length()).map { index ->
                val post = posts.getJSONObject(index)
                val postAuthor = post.optJSONObject("author") ?: JSONObject()
                Comment(
                    content = post.optString("content"),
                    floor = post.optInt("floor"),
                    createdAt = post.optString("created_at"),
                    likeCount = post.optInt("like_count"),
                    author = Author(
                        postAuthor.optString("nickname", "用户"),
                        postAuthor.optString("avatar"),
                    ),
                )
            },
        )
    }
}
