package com.qingtan.hjyzbbs.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import com.qingtan.hjyzbbs.core.AppConfig
import com.qingtan.hjyzbbs.ui.ForumViewModel
import com.qingtan.hjyzbbs.ui.theme.BrandColor

private data class MeAction(val icon: ImageVector, val label: String)

@Composable
fun MeScreen(viewModel: ForumViewModel, padding: PaddingValues, onLogin: () -> Unit) {
    if (!viewModel.loggedIn) {
        GuestContent(padding, onLogin)
    } else {
        LoggedInContent(viewModel, padding)
    }
}

@Composable
private fun GuestContent(padding: PaddingValues, onLogin: () -> Unit) {
    Box(Modifier.padding(padding).fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(
                Icons.Outlined.Person,
                null,
                Modifier.size(84.dp),
                MaterialTheme.colorScheme.primary,
            )
            Text("当前为游客模式", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Text("登录后可发帖、回复、收藏、签到", color = Color.Gray, modifier = Modifier.padding(8.dp))
            Button(onLogin) { Text("登录 / 注册") }
            TextButton(onClick = {}) {
                Icon(Icons.Outlined.Settings, null)
                Text("设置")
            }
        }
    }
}

@Composable
private fun LoggedInContent(viewModel: ForumViewModel, padding: PaddingValues) {
    LazyColumn(
        Modifier.padding(padding),
        contentPadding = PaddingValues(12.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        item {
            Text(
                "我的",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(4.dp),
            )
        }
        item { ProfileCard(viewModel) }
        item { QuickActions() }
        item {
            ListItem(
                headlineContent = { Text("设置") },
                leadingContent = { Icon(Icons.Outlined.Settings, null) },
            )
            ListItem(
                headlineContent = { Text("赞助名单") },
                leadingContent = { Icon(Icons.Outlined.VolunteerActivism, null) },
            )
            TextButton(viewModel::logout, Modifier.fillMaxWidth()) { Text("退出登录") }
        }
    }
}

@Composable
private fun ProfileCard(viewModel: ForumViewModel) {
    val user = viewModel.user
    Card {
        Row(
            Modifier.fillMaxWidth().padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            AsyncImage(
                user?.optString("avatar").orEmpty().ifBlank { AppConfig.DEFAULT_AVATAR },
                null,
                Modifier.size(62.dp).clip(CircleShape),
                contentScale = ContentScale.Crop,
            )
            Column(Modifier.weight(1f).padding(start = 12.dp)) {
                Text(
                    user?.optString("nickname", "用户") ?: "用户",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                )
                Text("积分 ${user?.optString("score", "0") ?: "0"}", color = Color.Gray)
                Text("点击进入个人主页", color = Color.Gray, style = MaterialTheme.typography.labelSmall)
            }
            Icon(Icons.Outlined.ChevronRight, null)
        }
    }
}

@Composable
private fun QuickActions() {
    val actions = listOf(
        MeAction(Icons.Outlined.Mail, "消息"),
        MeAction(Icons.Outlined.Article, "我的帖子"),
        MeAction(Icons.Outlined.StarBorder, "我的收藏"),
        MeAction(Icons.Outlined.History, "浏览历史"),
        MeAction(Icons.Outlined.Dashboard, "创作中心"),
        MeAction(Icons.Outlined.Download, "下载管理"),
        MeAction(Icons.Outlined.Security, "账号安全"),
        MeAction(Icons.Outlined.Person, "个人主页"),
    )
    Card {
        Column {
            actions.chunked(4).forEach { row ->
                Row(Modifier.fillMaxWidth()) {
                    row.forEach { action ->
                        Column(
                            Modifier.weight(1f).padding(vertical = 12.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            Icon(action.icon, null, tint = BrandColor)
                            Text(
                                action.label,
                                style = MaterialTheme.typography.labelSmall,
                                modifier = Modifier.padding(top = 5.dp),
                            )
                        }
                    }
                }
            }
        }
    }
}
