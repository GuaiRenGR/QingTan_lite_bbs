package com.qingtan.hjyzbbs.ui

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.outlined.BubbleChart
import androidx.compose.material.icons.outlined.Build
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.qingtan.hjyzbbs.ui.screens.DetailScreen
import com.qingtan.hjyzbbs.ui.screens.HomeScreen
import com.qingtan.hjyzbbs.ui.screens.LoginScreen
import com.qingtan.hjyzbbs.ui.screens.MeScreen
import com.qingtan.hjyzbbs.ui.screens.PlaceholderScreen
import com.qingtan.hjyzbbs.ui.theme.BrandColor
import com.qingtan.hjyzbbs.ui.theme.ForumTheme

@Composable
fun ForumApp(viewModel: ForumViewModel = viewModel()) {
    var selectedTab by remember { mutableIntStateOf(0) }
    var detailId by remember { mutableStateOf<Int?>(null) }
    var showLogin by remember { mutableStateOf(false) }

    ForumTheme {
        when {
            detailId != null -> DetailScreen(detailId!!, viewModel) { detailId = null }
            showLogin -> LoginScreen(viewModel) { showLogin = false }
            else -> Scaffold(
                bottomBar = {
                    MainNavigation(
                        selected = selectedTab,
                        onSelect = { selectedTab = it },
                        onCreate = { if (!viewModel.loggedIn) showLogin = true },
                    )
                },
            ) { padding ->
                when (selectedTab) {
                    0 -> HomeScreen(viewModel, padding) { detailId = it }
                    4 -> MeScreen(viewModel, padding) { showLogin = true }
                    else -> PlaceholderScreen(
                        padding,
                        if (selectedTab == 1) "动态" else "工具",
                    )
                }
            }
        }
    }
}

@Composable
private fun MainNavigation(
    selected: Int,
    onSelect: (Int) -> Unit,
    onCreate: () -> Unit,
) {
    NavigationBar {
        NavigationBarItem(
            selected = selected == 0,
            onClick = { onSelect(0) },
            icon = { Icon(if (selected == 0) Icons.Filled.Home else Icons.Outlined.Home, null) },
            label = { Text("首页") },
        )
        NavigationBarItem(
            selected = selected == 1,
            onClick = { onSelect(1) },
            icon = { Icon(Icons.Outlined.BubbleChart, null) },
            label = { Text("动态") },
        )
        NavigationBarItem(
            selected = false,
            onClick = onCreate,
            icon = {
                Surface(color = BrandColor, shape = RoundedCornerShape(12.dp)) {
                    Icon(
                        Icons.Filled.Add,
                        "发布帖子",
                        Modifier.padding(horizontal = 12.dp, vertical = 5.dp),
                        tint = Color.White,
                    )
                }
            },
        )
        NavigationBarItem(
            selected = selected == 3,
            onClick = { onSelect(3) },
            icon = { Icon(Icons.Outlined.Build, null) },
            label = { Text("工具") },
        )
        NavigationBarItem(
            selected = selected == 4,
            onClick = { onSelect(4) },
            icon = { Icon(if (selected == 4) Icons.Filled.Person else Icons.Outlined.Person, null) },
            label = { Text("我的") },
        )
    }
}
