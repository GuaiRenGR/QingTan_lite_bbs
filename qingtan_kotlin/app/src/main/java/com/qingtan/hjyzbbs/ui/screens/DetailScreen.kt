package com.qingtan.hjyzbbs.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import com.qingtan.hjyzbbs.core.AppConfig
import com.qingtan.hjyzbbs.data.model.Comment
import com.qingtan.hjyzbbs.data.model.ThreadDetail
import com.qingtan.hjyzbbs.ui.ForumViewModel
import com.qingtan.hjyzbbs.ui.components.ErrorView
import com.qingtan.hjyzbbs.ui.components.LoadingView

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DetailScreen(threadId: Int, viewModel: ForumViewModel, onBack: () -> Unit) {
    var detail by remember(threadId) { mutableStateOf<ThreadDetail?>(null) }
    var error by remember(threadId) { mutableStateOf<String?>(null) }

    LaunchedEffect(threadId) {
        viewModel.fetchDetail(threadId)
            .onSuccess { detail = it }
            .onFailure { error = it.message }
    }
    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(detail?.title ?: "帖子详情", maxLines = 1, overflow = TextOverflow.Ellipsis)
                },
                navigationIcon = {
                    IconButton(onBack) { Icon(Icons.Outlined.ArrowBack, "返回") }
                },
            )
        },
    ) { padding ->
        when {
            error != null -> ErrorView(error, onBack)
            detail == null -> LoadingView()
            else -> DetailContent(detail!!, padding)
        }
    }
}

@Composable
private fun DetailContent(detail: ThreadDetail, padding: PaddingValues) {
    LazyColumn(
        Modifier.padding(padding),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            AuthorHeader(detail)
            Text(
                detail.title,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(top = 14.dp),
            )
            Text(
                "${detail.views} 浏览 · ${detail.likes} 喜欢 · ${detail.replies} 回复",
                color = Color.Gray,
                style = MaterialTheme.typography.labelMedium,
            )
            Text(cleanContent(detail.content), style = MaterialTheme.typography.bodyLarge)
        }
        items(detail.images) { image ->
            AsyncImage(
                image,
                null,
                Modifier.fillMaxWidth().heightIn(max = 520.dp).clip(RoundedCornerShape(8.dp)),
                contentScale = ContentScale.FillWidth,
            )
        }
        item {
            HorizontalDivider()
            Text(
                "评论 ${detail.comments.size}",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
            )
        }
        items(detail.comments) { CommentItem(it) }
    }
}

@Composable
private fun AuthorHeader(detail: ThreadDetail) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        AsyncImage(
            detail.author.avatar.ifBlank { AppConfig.DEFAULT_AVATAR },
            null,
            Modifier.size(42.dp).clip(CircleShape),
            contentScale = ContentScale.Crop,
        )
        Column(Modifier.padding(start = 10.dp)) {
            Text(detail.author.name, fontWeight = FontWeight.Bold)
            Text(detail.createdAt, style = MaterialTheme.typography.labelSmall, color = Color.Gray)
        }
    }
}

@Composable
private fun CommentItem(comment: Comment) {
    Row(Modifier.fillMaxWidth()) {
        AsyncImage(
            comment.author.avatar.ifBlank { AppConfig.DEFAULT_AVATAR },
            null,
            Modifier.size(34.dp).clip(CircleShape),
            contentScale = ContentScale.Crop,
        )
        Column(Modifier.padding(start = 10.dp)) {
            Row {
                Text(comment.author.name, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                Text("${comment.floor}楼", color = Color.Gray, style = MaterialTheme.typography.labelSmall)
            }
            Text(cleanContent(comment.content), modifier = Modifier.padding(vertical = 5.dp))
            Text(
                "${comment.createdAt} · ${comment.likeCount} 赞",
                color = Color.Gray,
                style = MaterialTheme.typography.labelSmall,
            )
        }
    }
}

private fun cleanContent(value: String) = value
    .replace(Regex("<[^>]+>"), "")
    .replace(Regex("\\[/?[a-zA-Z][^]]*]"), "")
    .trim()
    .ifBlank { "暂无正文" }
