<template>
  <div class="app-container home">
    <el-row :gutter="16">
      <el-col :xs="24" :lg="16">
        <el-card shadow="never" class="home-card">
          <template #header>
            <div class="card-header">
              <span>FrameLean 更新后台</span>
              <el-button type="primary" icon="Promotion" @click="router.push('/framelean/releases')">发布版本</el-button>
            </div>
          </template>
          <el-descriptions :column="1" border>
            <el-descriptions-item label="客户端协议">/api/v1/releases/latest、download-ticket、Sparkle appcast</el-descriptions-item>
            <el-descriptions-item label="分发策略">COS 私有桶 + 后端短期票据 + COS 预签名 URL</el-descriptions-item>
            <el-descriptions-item label="后台能力">发布版本、制品登记、审计、IP 屏蔽、运行诊断</el-descriptions-item>
          </el-descriptions>
        </el-card>
      </el-col>
      <el-col :xs="24" :lg="8">
        <el-card shadow="never" class="home-card">
          <template #header>
            <span>快捷入口</span>
          </template>
          <div class="quick-actions">
            <el-button icon="Files" @click="router.push('/framelean/releases')">发布版本</el-button>
            <el-button icon="Tickets" @click="router.push('/framelean/audit')">更新审计</el-button>
            <el-button icon="Monitor" @click="router.push('/framelean/diagnostics')">运行诊断</el-button>
          </div>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup name="Index" lang="ts">
const router = useRouter();
</script>

<style lang="scss" scoped>
.home-card {
  margin-bottom: 16px;
}

.card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.quick-actions {
  display: grid;
  gap: 12px;

  :deep(.el-button) {
    justify-content: flex-start;
    margin-left: 0;
  }
}
</style>
