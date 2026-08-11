package com.qingtan.hjyzbbs.data.model

data class FeedThread(
    val id: Int,
    val title: String,
    val summary: String,
    val cover: String,
    val coverWidth: Int,
    val coverHeight: Int,
    val likeCount: Int,
    val replyCount: Int,
    val isTop: Boolean,
    val isDigest: Boolean,
    val authorName: String,
    val authorAvatar: String,
)

data class Author(val name: String, val avatar: String)

data class Comment(
    val content: String,
    val floor: Int,
    val createdAt: String,
    val likeCount: Int,
    val author: Author,
)

data class ThreadDetail(
    val title: String,
    val content: String,
    val images: List<String>,
    val views: Int,
    val replies: Int,
    val likes: Int,
    val createdAt: String,
    val author: Author,
    val comments: List<Comment>,
)

data class FeedState(
    val items: List<FeedThread> = emptyList(),
    val page: Int = 1,
    val hasMore: Boolean = true,
    val loading: Boolean = false,
    val error: String? = null,
)

data class ApiResult(val data: Any?, val message: String, val code: Int)
