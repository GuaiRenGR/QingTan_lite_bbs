package com.qingtan.hjyzbbs.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

val BrandColor = Color(0xFFFB7299)

@Composable
fun ForumTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = lightColorScheme(
            primary = BrandColor,
            secondary = Color(0xFF42A5F5),
            background = Color(0xFFF7F7F9),
            surface = Color.White,
        ),
        content = content,
    )
}
