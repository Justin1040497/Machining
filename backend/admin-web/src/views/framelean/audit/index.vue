<template>
  <div class="app-container framelean-page">
    <el-row :gutter="16" class="summary-row">
      <el-col :xs="24" :sm="8">
        <el-statistic title="累计下载" :value="dashboard.totalDownloads" />
      </el-col>
      <el-col :xs="24" :sm="8">
        <el-statistic title="更新检查" :value="dashboard.totalUpdateChecks" />
      </el-col>
      <el-col :xs="24" :sm="8">
        <el-statistic title="启用屏蔽 IP" :value="dashboard.activeBlockedIps" />
      </el-col>
    </el-row>

    <el-tabs v-model="activeTab" @tab-change="handleTabChange">
      <el-tab-pane label="更新检查" name="checks">
        <el-card shadow="never">
          <template #header>
            <div class="card-header">
              <span>更新检查审计</span>
              <el-button icon="Refresh" @click="loadChecks">刷新</el-button>
            </div>
          </template>
          <el-form :inline="true" :model="checkQuery">
            <el-form-item label="IP">
              <el-input v-model="checkQuery.ipAddress" clearable placeholder="客户端 IP" />
            </el-form-item>
            <el-form-item label="平台">
              <el-select v-model="checkQuery.platform" clearable placeholder="全部" style="width: 190px">
                <el-option label="Windows 安装器" value="windows-installer" />
                <el-option label="macOS Universal 2" value="macos-universal2" />
                <el-option label="Windows ZIP" value="windows-x64" />
              </el-select>
            </el-form-item>
            <el-form-item label="屏蔽">
              <el-select v-model="checkQuery.blocked" clearable placeholder="全部" style="width: 120px">
                <el-option label="是" :value="true" />
                <el-option label="否" :value="false" />
              </el-select>
            </el-form-item>
            <el-form-item>
              <el-button type="primary" icon="Search" @click="loadChecks">查询</el-button>
            </el-form-item>
          </el-form>
          <el-table v-loading="checksLoading" :data="checks.items" row-key="id">
            <el-table-column prop="createdAt" label="时间" min-width="180">
              <template #default="{ row }">{{ formatTime(row.createdAt) }}</template>
            </el-table-column>
            <el-table-column prop="platform" label="平台" min-width="160" />
            <el-table-column prop="currentVersion" label="当前版本" width="120" />
            <el-table-column prop="currentBuild" label="构建" width="90" />
            <el-table-column prop="releaseVersion" label="命中版本" width="120" />
            <el-table-column prop="ipAddress" label="IP" width="150" />
            <el-table-column prop="installId" label="安装 ID" min-width="180" show-overflow-tooltip />
            <el-table-column label="有更新" width="100">
              <template #default="{ row }">
                <el-tag :type="row.updateAvailable ? 'success' : 'info'">{{ row.updateAvailable ? '是' : '否' }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column label="屏蔽" width="90">
              <template #default="{ row }">
                <el-tag :type="row.blocked ? 'danger' : 'info'">{{ row.blocked ? '是' : '否' }}</el-tag>
              </template>
            </el-table-column>
          </el-table>
          <pagination v-show="checks.total > 0" v-model:page="checkQuery.page" v-model:limit="checkQuery.pageSize" :total="checks.total" @pagination="loadChecks" />
        </el-card>
      </el-tab-pane>

      <el-tab-pane label="下载事件" name="downloads">
        <el-card shadow="never">
          <template #header>
            <div class="card-header">
              <span>下载审计</span>
              <el-button icon="Refresh" @click="loadDownloads">刷新</el-button>
            </div>
          </template>
          <el-form :inline="true" :model="downloadQuery">
            <el-form-item label="IP">
              <el-input v-model="downloadQuery.ipAddress" clearable placeholder="客户端 IP" />
            </el-form-item>
            <el-form-item label="平台">
              <el-select v-model="downloadQuery.platform" clearable placeholder="全部" style="width: 190px">
                <el-option label="Windows 安装器" value="windows-installer" />
                <el-option label="macOS Universal 2" value="macos-universal2" />
                <el-option label="Windows ZIP" value="windows-x64" />
              </el-select>
            </el-form-item>
            <el-form-item label="Release ID">
              <el-input-number v-model="downloadQuery.releaseId" :min="1" :controls="false" clearable />
            </el-form-item>
            <el-form-item>
              <el-button type="primary" icon="Search" @click="loadDownloads">查询</el-button>
            </el-form-item>
          </el-form>
          <el-table v-loading="downloadsLoading" :data="downloads.items" row-key="id">
            <el-table-column prop="createdAt" label="时间" min-width="180">
              <template #default="{ row }">{{ formatTime(row.createdAt) }}</template>
            </el-table-column>
            <el-table-column prop="releaseVersion" label="版本" width="120" />
            <el-table-column prop="platform" label="平台" min-width="160" />
            <el-table-column prop="arch" label="架构" width="100" />
            <el-table-column prop="ipAddress" label="IP" width="150" />
            <el-table-column prop="installId" label="安装 ID" min-width="200" show-overflow-tooltip />
          </el-table>
          <pagination
            v-show="downloads.total > 0"
            v-model:page="downloadQuery.page"
            v-model:limit="downloadQuery.pageSize"
            :total="downloads.total"
            @pagination="loadDownloads"
          />
        </el-card>
      </el-tab-pane>

      <el-tab-pane label="IP 屏蔽" name="blocks">
        <el-card shadow="never">
          <template #header>
            <div class="card-header">
              <span>IP 屏蔽规则</span>
              <div class="card-actions">
                <el-button icon="Refresh" @click="loadBlocks">刷新</el-button>
                <el-button type="primary" icon="Plus" @click="blockDialogVisible = true">新增规则</el-button>
              </div>
            </div>
          </template>
          <el-form :inline="true" :model="blockQuery">
            <el-form-item label="IP">
              <el-input v-model="blockQuery.ipAddress" clearable placeholder="客户端 IP" />
            </el-form-item>
            <el-form-item>
              <el-button type="primary" icon="Search" @click="loadBlocks">查询</el-button>
            </el-form-item>
          </el-form>
          <el-table v-loading="blocksLoading" :data="blocks.items" row-key="id">
            <el-table-column prop="ipAddress" label="IP" width="160" />
            <el-table-column prop="reason" label="原因" min-width="220" show-overflow-tooltip />
            <el-table-column label="状态" width="100">
              <template #default="{ row }">
                <el-tag :type="row.enabled ? 'danger' : 'info'">{{ row.enabled ? '启用' : '停用' }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="createdAt" label="创建时间" min-width="180">
              <template #default="{ row }">{{ formatTime(row.createdAt) }}</template>
            </el-table-column>
            <el-table-column prop="updatedAt" label="更新时间" min-width="180">
              <template #default="{ row }">{{ formatTime(row.updatedAt) }}</template>
            </el-table-column>
            <el-table-column label="操作" width="110" fixed="right">
              <template #default="{ row }">
                <el-button v-if="row.enabled" link type="primary" icon="CircleClose" @click="handleDisableBlock(row.id)">停用</el-button>
              </template>
            </el-table-column>
          </el-table>
          <pagination v-show="blocks.total > 0" v-model:page="blockQuery.page" v-model:limit="blockQuery.pageSize" :total="blocks.total" @pagination="loadBlocks" />
        </el-card>
      </el-tab-pane>
    </el-tabs>

    <el-dialog v-model="blockDialogVisible" title="新增 IP 屏蔽" width="460px">
      <el-form label-width="80px" :model="blockForm">
        <el-form-item label="IP" required>
          <el-input v-model="blockForm.ipAddress" placeholder="203.0.113.10" />
        </el-form-item>
        <el-form-item label="原因">
          <el-input v-model="blockForm.reason" type="textarea" :rows="4" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="blockDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="handleCreateBlock">创建</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue';
import { createIpBlock, disableIpBlock, getDashboard, listDownloadEvents, listIpBlocks, listUpdateChecks } from '@/api/framelean';
import type { DashboardResponse, DownloadEventRecord, IpBlockRule, PageResponse, UpdateCheckRecord } from '@/api/framelean/types';

type TabName = 'checks' | 'downloads' | 'blocks';

const activeTab = ref<TabName>('checks');
const checksLoading = ref(false);
const downloadsLoading = ref(false);
const blocksLoading = ref(false);
const blockDialogVisible = ref(false);

const dashboard = reactive<DashboardResponse>({
  totalDownloads: 0,
  totalUpdateChecks: 0,
  distinctDownloadIps: 0,
  distinctCheckIps: 0,
  activeBlockedIps: 0
});

const checks = reactive<PageResponse<UpdateCheckRecord>>({ items: [], total: 0, page: 1, pageSize: 20 });
const downloads = reactive<PageResponse<DownloadEventRecord>>({ items: [], total: 0, page: 1, pageSize: 20 });
const blocks = reactive<PageResponse<IpBlockRule>>({ items: [], total: 0, page: 1, pageSize: 20 });

const checkQuery = reactive({ ipAddress: '', platform: '', blocked: undefined as boolean | undefined, page: 1, pageSize: 20 });
const downloadQuery = reactive({ ipAddress: '', platform: '', releaseId: undefined as number | undefined, page: 1, pageSize: 20 });
const blockQuery = reactive({ ipAddress: '', page: 1, pageSize: 20 });
const blockForm = reactive({ ipAddress: '', reason: '' });

const cleanQuery = (query: Record<string, unknown>) => {
  return Object.fromEntries(Object.entries(query).filter(([, value]) => value !== '' && value !== undefined && value !== null));
};

const loadDashboard = async () => {
  Object.assign(dashboard, await getDashboard());
};

const loadChecks = async () => {
  checksLoading.value = true;
  try {
    Object.assign(checks, await listUpdateChecks(cleanQuery(checkQuery)));
  } finally {
    checksLoading.value = false;
  }
};

const loadDownloads = async () => {
  downloadsLoading.value = true;
  try {
    Object.assign(downloads, await listDownloadEvents(cleanQuery(downloadQuery)));
  } finally {
    downloadsLoading.value = false;
  }
};

const loadBlocks = async () => {
  blocksLoading.value = true;
  try {
    Object.assign(blocks, await listIpBlocks(cleanQuery(blockQuery)));
  } finally {
    blocksLoading.value = false;
  }
};

const handleTabChange = (name: TabName) => {
  if (name === 'checks') {
    loadChecks();
  } else if (name === 'downloads') {
    loadDownloads();
  } else {
    loadBlocks();
  }
};

const handleCreateBlock = async () => {
  if (!blockForm.ipAddress.trim()) {
    ElMessage.warning('请填写 IP 地址');
    return;
  }
  await createIpBlock({ ipAddress: blockForm.ipAddress.trim(), reason: blockForm.reason });
  ElMessage.success('屏蔽规则已创建');
  blockDialogVisible.value = false;
  blockForm.ipAddress = '';
  blockForm.reason = '';
  await Promise.all([loadBlocks(), loadDashboard()]);
};

const handleDisableBlock = async (id: number) => {
  await disableIpBlock(id);
  ElMessage.success('屏蔽规则已停用');
  await Promise.all([loadBlocks(), loadDashboard()]);
};

const formatTime = (value?: string) => {
  if (!value) {
    return '-';
  }
  return new Date(value).toLocaleString();
};

onMounted(async () => {
  await Promise.all([loadDashboard(), loadChecks()]);
});
</script>

<style scoped lang="scss">
.summary-row {
  margin-bottom: 16px;
}

.card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.card-actions {
  display: flex;
  gap: 8px;
}
</style>
