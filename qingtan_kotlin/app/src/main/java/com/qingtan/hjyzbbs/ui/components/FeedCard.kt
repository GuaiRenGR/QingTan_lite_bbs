package com.qingtan.hjyzbbs.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Article
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import com.qingtan.hjyzbbs.core.AppConfig
import com.qingtan.hjyzbbs.data.model.FeedThread

@Composable
fun FeedCard(thread: FeedThread, onClick: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
    ) {
        Column {
            FeedCover(thread)
            Column(Modifier.padding(start = 8.dp, top = 7.dp, end = 8.dp, bottom = 6.dp)) {
                Text(
                    thread.title,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    fontWeight = FontWeight.Bold,
                )
                Row(Modifier.padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                    AsyncImage(
                        thread.authorAvatar.ifBlank { AppConfig.DEFAULT_AVATAR },
                        null,
                        Modifier.size(20.dp).clip(CircleShape),
                        contentScale = ContentScale.Crop,
                    )
                    Text(
                        thread.authorName,
                        Modifier.weight(1f).padding(start = 5.dp),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        style = MaterialTheme.typography.labelSmall,
                        color = Color.Gray,
                    )
                    Icon(Icons.Outlined.FavoriteBorder, null, Modifier.size(15.dp), Color.Gray)
                    Text("${thread.likeCount}", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
                }
            }
        }
    }
}

@Composable
private fun FeedCover(thread: FeedThread) {
    Box {
        if (thread.cover.isNotBlank()) {
            val ratio = if (thread.coverWidth > 0 && thread.coverHeight > 0) {
                thread.coverWidth.toFloat() / thread.coverHeight
            } else {
                1.25f
            }
            AsyncImage(
                thread.cover,
                null,
                Modifier.fillMaxWidth().aspectRatio(ratio.coerceIn(.55f, 2f)),
                contentScale = ContentScale.Crop,
            )
        } else {
            Box(
                Modifier.fillMaxWidth()
                    .height((120 + (thread.id % 5) * 15).dp)
                    .background(
                        Brush.linearGradient(listOf(Color(0xFFFFF1F5), Color(0xFFF0F7FF))),
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Outlined.Article, null, Modifier.size(38.dp), Color.Gray)
            }
        }
        Row(Modifier.padding(6.dp)) {
            if (thread.isTop) FeedBadge("置顶", Color.Red)
            if (thread.isDigest) FeedBadge("精华", Color(0xFFFF9800))
        }
        Surface(
            Modifier.align(Alignment.BottomEnd).padding(6.dp),
            color = Color.Black.copy(alpha = .45f),
            shape = RoundedCornerShape(10.dp),
        ) {
            Text(
                "◯ ${thread.replyCount}",
                color = Color.White,
                style = MaterialTheme.typography.labelSmall,
                modifier = Modifier.padding(horizontal = 6.dp, vertical = 3.dp),
            )
        }
    }
}

@Composable
private fun FeedBadge(text: String, color: Color) {
    Surface(
        color = color.copy(alpha = .9f),
        shape = RoundedCornerShape(4.dp),
        modifier = Modifier.padding(end = 4.dp),
    ) {
        Text(
            text,
            color = Color.White,
            style = MaterialTheme.typography.labelSmall,
            modifier = Modifier.padding(horizontal = 5.dp, vertical = 2.dp),
        )
    }
}
