package com.qingtan.hjyzbbs.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.qingtan.hjyzbbs.ui.ForumViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LoginScreen(viewModel: ForumViewModel, onBack: () -> Unit) {
    var account by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("登录") },
                navigationIcon = {
                    IconButton(onBack) { Icon(Icons.Outlined.ArrowBack, "返回") }
                },
            )
        },
    ) { padding ->
        Column(
            Modifier.padding(padding).padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Spacer(Modifier.height(40.dp))
            Text("欢迎回来", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.ExtraBold)
            Text("不登录也可以浏览社区内容", color = Color.Gray)
            OutlinedTextField(
                account,
                { account = it },
                Modifier.fillMaxWidth(),
                label = { Text("用户名 / 邮箱") },
                singleLine = true,
            )
            OutlinedTextField(
                password,
                { password = it },
                Modifier.fillMaxWidth(),
                label = { Text("密码") },
                singleLine = true,
                visualTransformation = PasswordVisualTransformation(),
            )
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            Button(
                onClick = {
                    if (account.isBlank() || password.isBlank()) {
                        error = "请输入账号和密码"
                    } else {
                        viewModel.login(account.trim(), password) { message ->
                            if (message == null) onBack() else error = message
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                enabled = !viewModel.authLoading,
            ) {
                if (viewModel.authLoading) {
                    CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
                } else {
                    Text("登录")
                }
            }
            TextButton(onBack, Modifier.align(Alignment.CenterHorizontally)) {
                Text("先不登录，继续浏览")
            }
        }
    }
}
