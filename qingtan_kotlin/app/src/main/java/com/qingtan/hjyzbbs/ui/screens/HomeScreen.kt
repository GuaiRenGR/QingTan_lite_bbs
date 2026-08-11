package com.qingtan.hjyzbbs.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.staggeredgrid.LazyVerticalStaggeredGrid
import androidx.compose.foundation.lazy.staggeredgrid.StaggeredGridCells
import androidx.compose.foundation.lazy.staggeredgrid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Mail
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import com.qingtan.hjyzbbs.core.AppConfig
import com.qingtan.hjyzbbs.data.model.FeedState
import com.qingtan.hjyzbbs.ui.ForumViewModel
import com.qingtan.hjyzbbs.ui.components.ErrorView
import com.qingtan.hjyzbbs.ui.components.FeedCard
import com.qingtan.hjyzbbs.ui.components.LoadingView

@Composable
fun HomeScreen(viewModel: ForumViewModel, padding: PaddingValues, openThread: (Int) -> Unit) {
    val tabs = listOf("推荐" to "recommend", "热门" to "hot", "精华" to "digest", "最新" to "latest")
    var selected by remember { mutableIntStateOf(0) }
    val channel = tabs[selected].second
    val state = viewModel.feeds[channel] ?: FeedState()

    Column(Modifier.padding(padding).fillMaxSize()) {
        HomeTopBar(viewModel.user?.optString("avatar").orEmpty())
        ScrollableTabRow(selected, edgePadding = 10.dp, divider = {}) {
            tabs.forEachIndexed { index, tab ->
                Tab(selected == index, { selected = index }, text = { Text(tab.first) })
            }
        }
        when {
            state.loading && state.items.isEmpty() -> LoadingView()
            state.error != null && state.items.isEmpty() -> ErrorView(state.error) {
                viewModel.refresh(channel)
            }
            else -> FeedGrid(state, viewModel, channel, openThread)
        }
    }
}

@Composable
private fun FeedGrid(
    state: FeedState,
    viewModel: ForumViewModel,
    channel: String,
    openThread: (Int) -> Unit,
) {
    LazyVerticalStaggeredGrid(
        columns = StaggeredGridCells.Adaptive(160.dp),
        contentPadding = PaddingValues(8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalItemSpacing = 8.dp,
    ) {
        items(state.items, key = { it.id }) { thread ->
            FeedCard(thread) { openThread(thread.id) }
        }
        item {
            Box(Modifier.fillMaxWidth().padding(12.dp), contentAlignment = Alignment.Center) {
                if (state.loading) {
                    CircularProgressIndicator(Modifier.size(24.dp))
                } else if (state.hasMore) {
                    TextButton({ viewModel.loadMore(channel) }) { Text("加载更多") }
                }
            }
        }
    }
}

@Composable
private fun HomeTopBar(avatar: String) {
    Row(
        Modifier.fillMaxWidth().background(Color.White).statusBarsPadding()
            .padding(start = 12.dp, top = 6.dp, end = 12.dp, bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        AsyncImage(
            avatar.ifBlank { AppConfig.DEFAULT_AVATAR },
            null,
            Modifier.size(36.dp).clip(CircleShape),
            contentScale = ContentScale.Crop,
        )
        Surface(
            Modifier.weight(1f).padding(horizontal = 10.dp),
            color = Color(0xFFF2F2F4),
            shape = RoundedCornerShape(18.dp),
        ) {
            Row(
                Modifier.height(36.dp).padding(horizontal = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Outlined.Search, null, Modifier.size(20.dp), Color.Gray)
                Text("搜索帖子、版块、用户", color = Color.Gray, modifier = Modifier.padding(start = 6.dp))
            }
        }
        Icon(Icons.Outlined.Mail, "消息")
    }
}
