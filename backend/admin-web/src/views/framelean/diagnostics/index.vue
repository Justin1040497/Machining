<template>
  <div class="app-container framelean-page">
    <el-row :gutter="16" class="summary-row">
      <el-col :xs="24" :sm="6">
        <el-card shadow="never">
          <el-statistic title="API" :value="health.status || '-'" />
        </el-card>
      </el-col>
      <el-col :xs="24" :sm="6">
        <el-card shadow="never">
          <el-statistic title="COS" :value="diagnostics.cosConfigured ? '已配置' : '未配置'" />
        </el-card>
      </el-col>
      <el-col :xs="24" :sm="6">
        <el-card shadow="never">
          <el-statistic title="Redis" :value="diagnostics.redisConfigured ? '可用' : '不可用'" />
        </el-card>
      </el-col>
      <el-col :xs="24" :sm="6">
        <el-card shadow="never">
          <el-statistic title="兼容 API Key" :value="diagnostics.apiKeyConfigured ? '已配置' : '未配置'" />
        </el-card>
      </el-col>
    </el-row>

    <el-card shadow="never" class="diagnostic-card">
      <template #header>
        <div class="card-header">
          <span>运行诊断</span>
          <el-button icon="Refresh" :loading="loading" @click="loadDiagnostics">刷新</el-button>
        </div>
      </template>
      <el-descriptions :column="1" border>
        <el-descriptions-item label="公网根地址">{{ diagnostics.publicBaseUrl || '-' }}</el-descriptions-item>
        <el-descriptions-item label="下载票据 TTL">{{ diagnostics.updateTicketTtl || '-' }}</el-descriptions-item>
        <el-descriptions-item label="COS URL TTL">{{ diagnostics.downloadUrlTtl || '-' }}</el-descriptions-item>
        <el-descriptions-item label="COS 私有桶">
          <el-tag :type="diagnostics.cosConfigured ? 'success' : 'danger'">{{ diagnostics.cosConfigured ? '已配置' : '未配置' }}</el-tag>
        </el-descriptions-item>
        <el-descriptions-item label="Redis">
          <el-tag :type="diagnostics.redisConfigured ? 'success' : 'danger'">{{ diagnostics.redisConfigured ? '可用' : '不可用' }}</el-tag>
        </el-descriptions-item>
        <el-descriptions-item label="X-Api-Key 兼容层">
          <el-tag :type="diagnostics.apiKeyConfigured ? 'success' : 'warning'">{{ diagnostics.apiKeyConfigured ? '已配置' : '未配置' }}</el-tag>
        </el-descriptions-item>
      </el-descriptions>
    </el-card>

    <el-card shadow="never" class="diagnostic-card">
      <template #header>
        <span>公开端点</span>
      </template>
      <el-table :data="endpointRows" row-key="path">
        <el-table-column prop="method" label="方法" width="90" />
        <el-table-column prop="path" label="路径" min-width="300" />
        <el-table-column label="打开" width="110">
          <template #default="{ row }">
            <el-button link type="primary" icon="Link" @click="openEndpoint(row.path)">打开</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';
import { getDiagnostics, getHealth } from '@/api/framelean';
import type { DiagnosticsResponse, HealthResponse } from '@/api/framelean/types';

const loading = ref(false);
const diagnostics = reactive<DiagnosticsResponse>({
  publicBaseUrl: '',
  cosConfigured: false,
  redisConfigured: false,
  apiKeyConfigured: false,
  updateTicketTtl: '',
  downloadUrlTtl: ''
});
const health = reactive<HealthResponse>({
  status: ''
});

const endpointRows = computed(() => {
  const baseUrl = diagnostics.publicBaseUrl || '';
  return [
    { method: 'GET', path: `${baseUrl}/api/v1/health` },
    { method: 'GET', path: `${baseUrl}/api/v1/releases/latest?platform=windows-installer&currentVersion=0.0.0&currentBuild=0` },
    { method: 'GET', path: `${baseUrl}/api/v1/releases/notes` },
    { method: 'GET', path: `${baseUrl}/api/v1/sparkle/appcast.xml` }
  ];
});

const loadDiagnostics = async () => {
  loading.value = true;
  try {
    const [diagnosticRes, healthRes] = await Promise.all([getDiagnostics(), getHealth()]);
    Object.assign(diagnostics, diagnosticRes);
    Object.assign(health, healthRes);
  } finally {
    loading.value = false;
  }
};

const openEndpoint = (url: string) => {
  window.open(url, '_blank', 'noopener,noreferrer');
};

onMounted(loadDiagnostics);
</script>

<style scoped lang="scss">
.summary-row {
  margin-bottom: 16px;
}

.diagnostic-card {
  margin-bottom: 16px;
}

.card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}
</style>
