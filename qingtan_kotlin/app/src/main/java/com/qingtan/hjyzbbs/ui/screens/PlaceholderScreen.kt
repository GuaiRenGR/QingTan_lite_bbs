package com.qingtan.hjyzbbs.ui.screens

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color

@Composable
fun PlaceholderScreen(padding: PaddingValues, title: String) {
    Box(Modifier.padding(padding).fillMaxSize(), contentAlignment = Alignment.Center) {
        Text("$title（后续迁移）", color = Color.Gray)
    }
}
