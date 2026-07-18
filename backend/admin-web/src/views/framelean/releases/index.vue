<template>
  <div class="app-container framelean-page">
    <el-row :gutter="16" class="summary-row">
      <el-col :xs="24" :sm="8">
        <el-statistic title="发布版本" :value="releases.length" />
      </el-col>
      <el-col :xs="24" :sm="8">
        <el-statistic title="已发布" :value="publishedCount" />
      </el-col>
      <el-col :xs="24" :sm="8">
        <el-statistic title="累计下载" :value="totalDownloads" />
      </el-col>
    </el-row>

    <el-card shadow="never" class="table-card">
      <template #header>
        <div class="card-header">
          <span>发布版本</span>
          <div class="card-actions">
            <el-button icon="Refresh" @click="loadReleases">刷新</el-button>
            <el-button type="primary" icon="Plus" @click="openCreateDialog">创建草稿</el-button>
          </div>
        </div>
      </template>

      <el-table v-loading="loading" :data="releases" row-key="id">
        <el-table-column prop="version" label="版本" min-width="130" />
        <el-table-column prop="buildNumber" label="构建号" width="100" />
        <el-table-column prop="channel" label="渠道" width="100" />
        <el-table-column prop="status" label="状态" width="110">
          <template #default="{ row }">
            <el-tag :type="statusTagType(row.status)">{{ row.status }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="downloadCount" label="下载" width="100" />
        <el-table-column prop="createdAt" label="创建时间" min-width="180">
          <template #default="{ row }">{{ formatTime(row.createdAt) }}</template>
        </el-table-column>
        <el-table-column prop="publishedAt" label="发布时间" min-width="180">
          <template #default="{ row }">{{ formatTime(row.publishedAt) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="230" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" icon="View" @click="openRelease(row.version)">详情</el-button>
            <el-button v-if="isDraft(row)" link type="success" icon="Promotion" @click="handlePublish(row.version)">发布</el-button>
            <el-button link type="danger" icon="Delete" @click="handleDelete(row.version)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="createVisible" title="创建发布草稿" width="560px">
      <el-form label-width="110px" :model="createForm">
        <el-form-item label="版本号" required>
          <el-input v-model="createForm.version" placeholder="v1.2.2" />
        </el-form-item>
        <el-form-item label="构建号" required>
          <el-input-number v-model="createForm.buildNumber" :min="0" :controls="false" class="form-number" />
        </el-form-item>
        <el-form-item label="渠道">
          <el-input v-model="createForm.channel" />
        </el-form-item>
        <el-form-item label="最低构建">
          <el-input-number v-model="createForm.minSupportedBuild" :min="0" :controls="false" class="form-number" />
        </el-form-item>
        <el-form-item label="强制更新">
          <el-switch v-model="createForm.mandatory" />
        </el-form-item>
        <el-divider content-position="left">下载地址（可创建后再填写）</el-divider>
        <el-form-item label="GitHub 地址">
          <el-input v-model="createForm.githubDownloadUrl" placeholder="当前版本的 GitHub 下载页或 Release 地址" clearable />
        </el-form-item>
        <el-form-item label="Gitee 地址">
          <el-input v-model="createForm.giteeDownloadUrl" placeholder="当前版本的 Gitee 下载页或 Release 地址" clearable />
        </el-form-item>
        <el-form-item label="备用地址">
          <el-input v-model="createForm.backupDownloadUrl" placeholder="备用下载页地址" clearable />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="createVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="handleCreate">创建</el-button>
      </template>
    </el-dialog>

    <el-drawer v-model="detailVisible" :title="detailTitle" size="70%" append-to-body>
      <el-empty v-if="!detail" description="未选择版本" />
      <template v-else>
        <el-descriptions :column="3" border class="detail-block">
          <el-descriptions-item label="版本">{{ detail.version }}</el-descriptions-item>
          <el-descriptions-item label="构建号">{{ detail.buildNumber }}</el-descriptions-item>
          <el-descriptions-item label="状态">
            <el-tag :type="statusTagType(detail.status)">{{ detail.status }}</el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="渠道">{{ detail.channel }}</el-descriptions-item>
          <el-descriptions-item label="最低构建">{{ detail.minSupportedBuild }}</el-descriptions-item>
          <el-descriptions-item label="强制更新">{{ detail.mandatory ? '是' : '否' }}</el-descriptions-item>
        </el-descriptions>

        <el-row :gutter="16">
          <el-col :xs="24" :lg="12">
            <el-card shadow="never" class="detail-card">
              <template #header>
                <div class="card-header">
                  <span>发布元数据</span>
                  <el-button v-if="isDraft(detail)" type="primary" icon="Check" @click="saveMetadata">保存</el-button>
                </div>
              </template>
              <el-form label-width="92px">
                <el-form-item label="构建号">
                  <el-input-number v-model="buildDraft" :min="0" :controls="false" class="form-number" :disabled="!isDraft(detail)" />
                </el-form-item>
                <el-form-item label="版本日志">
                  <div v-if="isDraft(detail)" class="notes-upload-area">
                    <el-upload
                      ref="notesUploadRef"
                      drag
                      :auto-upload="false"
                      :limit="1"
                      :on-change="handleNotesFileChange"
                      :on-remove="handleNotesFileRemove"
                      :file-list="notesFileList"
                      accept=".md,.txt"
                    >
                      <el-icon class="el-icon--upload"><i-ep-upload-filled /></el-icon>
                      <div class="el-upload__text">将版本日志文件拖到此处，或<em>点击上传</em></div>
                      <template #tip>
                        <div class="el-upload__tip">支持 .md / .txt 文件</div>
                      </template>
                    </el-upload>
                  </div>
                  <div v-else-if="detail.notesObjectKey" class="notes-file-info">
                    <el-text type="info">{{ detail.notesObjectKey }}</el-text>
                  </div>
                  <el-text v-else type="info">未上传</el-text>
                </el-form-item>
              </el-form>
            </el-card>
          </el-col>

          <el-col :xs="24" :lg="12">
            <el-card shadow="never" class="detail-card">
              <template #header>
                <div class="card-header">
                  <span>下载地址</span>
                  <el-button v-if="isDraft(detail)" type="primary" icon="Check" @click="saveDownloadUrls">保存</el-button>
                </div>
              </template>
              <el-form label-width="100px">
                <el-form-item label="GitHub 地址">
                  <el-input
                    v-model="downloadUrlDraft.githubDownloadUrl"
                    :disabled="!isDraft(detail)"
                    placeholder="当前版本的 GitHub 下载页或 Release 地址"
                    clearable
                  />
                </el-form-item>
                <el-form-item label="Gitee 地址">
                  <el-input
                    v-model="downloadUrlDraft.giteeDownloadUrl"
                    :disabled="!isDraft(detail)"
                    placeholder="当前版本的 Gitee 下载页或 Release 地址"
                    clearable
                  />
                </el-form-item>
                <el-form-item label="备用地址">
                  <el-input
                    v-model="downloadUrlDraft.backupDownloadUrl"
                    :disabled="!isDraft(detail)"
                    placeholder="备用下载页地址"
                    clearable
                  />
                </el-form-item>
              </el-form>
              <el-alert
                title="现阶段客户端只展示更新日志和下载入口，不再直接下载 EXE / DMG / ZIP。原制品上传与自更新能力已保留但暂时隐藏。"
                type="info"
                show-icon
                :closable="false"
              />
            </el-card>

            <el-card v-if="enableArtifactUpload" shadow="never" class="detail-card">
              <template #header>
                <div class="card-header">
                  <span>COS 上传 URL</span>
                  <el-button icon="Link" @click="handleUploadUrl">生成</el-button>
                </div>
              </template>
              <el-form label-width="92px">
                <el-form-item label="Object Key">
                  <el-input v-model="uploadKey" placeholder="releases/v1.2.2/FrameLean-v1.2.2.dmg" />
                </el-form-item>
                <el-form-item v-if="uploadInfo" label="有效期">
                  <el-text>{{ formatTime(uploadInfo.expiresAt) }}</el-text>
                </el-form-item>
                <el-form-item v-if="uploadInfo" label="URL">
                  <el-input :model-value="uploadInfo.uploadUrl" type="textarea" :rows="4" readonly />
                </el-form-item>
              </el-form>
            </el-card>
          </el-col>
        </el-row>

        <el-card v-if="enableArtifactUpload" shadow="never" class="detail-card">
          <template #header>
            <span>发布要求</span>
          </template>
          <el-table :data="detail.requirements" row-key="platform">
            <el-table-column prop="platform" label="平台" min-width="170" />
            <el-table-column prop="arch" label="架构" width="140" />
            <el-table-column label="必填" width="110">
              <template #default="{ row }">
                <el-tag :type="row.required ? 'danger' : 'info'">{{ row.required ? '必填' : '可选' }}</el-tag>
              </template>
            </el-table-column>
          </el-table>
        </el-card>

        <el-card v-if="enableArtifactUpload" shadow="never" class="detail-card">
          <template #header>
            <div class="card-header">
              <span>制品登记</span>
            </div>
          </template>
          <div v-if="isDraft(detail)" class="package-upload-area">
            <el-upload
              ref="packageUploadRef"
              drag
              multiple
              :auto-upload="false"
              :on-change="handlePackageFileChange"
              :file-list="packageFileList"
              accept=".exe,.dmg,.zip"
            >
              <el-icon class="el-icon--upload"><i-ep-upload-filled /></el-icon>
              <div class="el-upload__text">将安装包文件拖到此处，或<em>点击上传</em></div>
              <template #tip>
                <div class="el-upload__tip">支持 .exe / .dmg / .zip，自动识别平台、文件名、大小、SHA-256</div>
              </template>
            </el-upload>
            <div v-if="pendingPackages.length > 0" class="pending-packages">
              <div v-for="(pkg, index) in pendingPackages" :key="index" class="pending-package-item">
                <el-descriptions :column="3" border size="small">
                  <el-descriptions-item label="平台">{{ pkg.platform }}</el-descriptions-item>
                  <el-descriptions-item label="文件名">{{ pkg.fileName }}</el-descriptions-item>
                  <el-descriptions-item label="大小">{{ formatBytes(pkg.size) }}</el-descriptions-item>
                  <el-descriptions-item label="Object Key">{{ pkg.objectKey }}</el-descriptions-item>
                  <el-descriptions-item label="SHA-256" :span="2">{{ pkg.sha256 }}</el-descriptions-item>
                </el-descriptions>
                <div class="pending-package-actions">
                  <el-input v-model="pkg.ed25519Signature" placeholder="签名（可选）" size="small" style="width: 260px" />
                  <el-button type="primary" size="small" @click="registerPackage(index)">登记</el-button>
                  <el-button size="small" @click="removePendingPackage(index)">移除</el-button>
                </div>
              </div>
            </div>
          </div>

          <el-table :data="detail.packages" row-key="id">
            <el-table-column prop="platform" label="平台" min-width="170" />
            <el-table-column prop="arch" label="架构" width="120" />
            <el-table-column prop="fileName" label="文件名" min-width="220" show-overflow-tooltip />
            <el-table-column prop="size" label="大小" width="120">
              <template #default="{ row }">{{ formatBytes(row.size) }}</template>
            </el-table-column>
            <el-table-column label="客户端可见" width="120">
              <template #default="{ row }">
                <el-tag :type="row.clientVisible ? 'success' : 'info'">{{ row.clientVisible ? '是' : '否' }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="sha256" label="SHA-256" min-width="220" show-overflow-tooltip />
          </el-table>
        </el-card>
      </template>
    </el-drawer>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';
import {
  addReleasePackage,
  createRelease,
  deleteRelease,
  getRelease,
  getUploadUrl,
  listReleases,
  publishRelease,
  updateReleaseBuildNumber,
  updateReleaseDownloadUrls,
  updateReleaseNotes
} from '@/api/framelean';
import type { CreatePackageRequest, CreateReleaseRequest, ReleaseDetail, ReleasePlatform, ReleaseStatus, ReleaseSummary, UploadUrlResponse } from '@/api/framelean/types';

const loading = ref(false);
const saving = ref(false);
const releases = ref<ReleaseSummary[]>([]);
const detail = ref<ReleaseDetail>();
const createVisible = ref(false);
const detailVisible = ref(false);
const notesFile = ref<File | null>(null);
const notesFileList = ref<any[]>([]);
const notesUploading = ref(false);
const notesUploadRef = ref<any>();
const buildDraft = ref(0);
const uploadKey = ref('');
const uploadInfo = ref<UploadUrlResponse>();
const enableArtifactUpload = false;

const downloadUrlDraft = reactive({
  githubDownloadUrl: '',
  giteeDownloadUrl: '',
  backupDownloadUrl: ''
});

const platformOptions: Array<{ label: string; value: ReleasePlatform; arch: string; visible: boolean }> = [
  { label: 'Windows 安装器 (.exe)', value: 'windows-installer', arch: 'x64', visible: true },
  { label: 'macOS Universal 2 (.dmg)', value: 'macos-universal2', arch: 'universal2', visible: true },
  { label: 'Windows 便携 ZIP', value: 'windows-x64', arch: 'x64', visible: false }
];

const createForm = reactive<CreateReleaseRequest>({
  version: '',
  buildNumber: 0,
  channel: 'stable',
  mandatory: false,
  minSupportedBuild: 0,
  notes: '',
  requiredArtifacts: [],
  packages: [],
  githubDownloadUrl: '',
  giteeDownloadUrl: '',
  backupDownloadUrl: ''
});

interface PendingPackage extends CreatePackageRequest {
  file: File;
}

const pendingPackages = ref<PendingPackage[]>([]);
const packageFileList = ref<any[]>([]);

const publishedCount = computed(() => releases.value.filter((release) => release.status === 'published').length);
const totalDownloads = computed(() => releases.value.reduce((sum, release) => sum + (release.downloadCount || 0), 0));
const detailTitle = computed(() => (detail.value ? `版本详情 ${detail.value.version}` : '版本详情'));

const isDraft = (release: ReleaseSummary | ReleaseDetail) => release.status === 'draft';

const statusTagType = (status: ReleaseStatus) => {
  if (status === 'published') {
    return 'success';
  }
  if (status === 'archived') {
    return 'warning';
  }
  return 'info';
};

const loadReleases = async () => {
  loading.value = true;
  try {
    const res = await listReleases();
    releases.value = res.releases ?? [];
  } finally {
    loading.value = false;
  }
};

const openCreateDialog = () => {
  createForm.version = '';
  createForm.buildNumber = 0;
  createForm.channel = 'stable';
  createForm.mandatory = false;
  createForm.minSupportedBuild = 0;
  createForm.notes = '';
  createForm.githubDownloadUrl = '';
  createForm.giteeDownloadUrl = '';
  createForm.backupDownloadUrl = '';
  createVisible.value = true;
};

const handleCreate = async () => {
  if (!createForm.version.trim()) {
    ElMessage.warning('请填写版本号');
    return;
  }
  saving.value = true;
  try {
    const created = await createRelease({
      ...createForm,
      version: createForm.version.trim(),
      channel: createForm.channel || 'stable',
      githubDownloadUrl: createForm.githubDownloadUrl?.trim(),
      giteeDownloadUrl: createForm.giteeDownloadUrl?.trim(),
      backupDownloadUrl: createForm.backupDownloadUrl?.trim()
    });
    ElMessage.success('草稿已创建');
    createVisible.value = false;
    await loadReleases();
    await openRelease(created.version);
  } finally {
    saving.value = false;
  }
};

const openRelease = async (version: string) => {
  const res = await getRelease(version);
  detail.value = res;
  notesFile.value = null;
  notesFileList.value = [];
  pendingPackages.value = [];
  buildDraft.value = res.buildNumber;
  uploadKey.value = `releases/${res.version}/`;
  uploadInfo.value = undefined;
  downloadUrlDraft.githubDownloadUrl = res.githubDownloadUrl || '';
  downloadUrlDraft.giteeDownloadUrl = res.giteeDownloadUrl || '';
  downloadUrlDraft.backupDownloadUrl = res.backupDownloadUrl || '';
  detailVisible.value = true;
};

const handleNotesFileChange = (uploadFile: any) => {
  notesFile.value = uploadFile.raw;
};

const handleNotesFileRemove = () => {
  notesFile.value = null;
};

const uploadNotesFile = async (version: string): Promise<string | undefined> => {
  if (!notesFile.value) {
    return undefined;
  }
  notesUploading.value = true;
  try {
    const objectKey = `releases/${version}/${notesFile.value.name}`;
    const { uploadUrl } = await getUploadUrl(objectKey);
    await fetch(uploadUrl, {
      method: 'PUT',
      body: notesFile.value,
      headers: { 'Content-Type': notesFile.value.type || 'application/octet-stream' }
    });
    return objectKey;
  } finally {
    notesUploading.value = false;
  }
};

const saveMetadata = async () => {
  if (!detail.value) {
    return;
  }
  const version = detail.value.version;
  await updateReleaseBuildNumber(version, buildDraft.value);
  const notesObjectKey = await uploadNotesFile(version);
  await updateReleaseNotes(version, '', notesObjectKey);
  await openRelease(version);
  await loadReleases();
  ElMessage.success('发布元数据已保存');
};

const saveDownloadUrls = async () => {
  if (!detail.value) {
    return;
  }
  const version = detail.value.version;
  await updateReleaseDownloadUrls(version, {
    githubDownloadUrl: downloadUrlDraft.githubDownloadUrl.trim(),
    giteeDownloadUrl: downloadUrlDraft.giteeDownloadUrl.trim(),
    backupDownloadUrl: downloadUrlDraft.backupDownloadUrl.trim()
  });
  await openRelease(version);
  await loadReleases();
  ElMessage.success('下载地址已保存');
};

const handleUploadUrl = async () => {
  if (!uploadKey.value.trim()) {
    ElMessage.warning('请填写 COS Object Key');
    return;
  }
  uploadInfo.value = await getUploadUrl(uploadKey.value.trim());
  ElMessage.success('上传 URL 已生成');
};

const detectPlatform = (fileName: string): { platform: ReleasePlatform; arch: string; clientVisible: boolean } => {
  const lower = fileName.toLowerCase();
  if (lower.endsWith('.exe')) {
    return { platform: 'windows-installer', arch: 'x64', clientVisible: true };
  }
  if (lower.endsWith('.dmg')) {
    return { platform: 'macos-universal2', arch: 'universal2', clientVisible: true };
  }
  if (lower.endsWith('.zip')) {
    return { platform: 'windows-x64', arch: 'x64', clientVisible: false };
  }
  throw new Error(`无法识别文件类型: ${fileName}`);
};

const computeSha256 = async (file: File): Promise<string> => {
  const buffer = await file.arrayBuffer();
  const hashBuffer = await crypto.subtle.digest('SHA-256', buffer);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
};

const handlePackageFileChange = async (uploadFile: any) => {
  const file = uploadFile.raw as File;
  try {
    const { platform, arch, clientVisible } = detectPlatform(file.name);
    const sha256 = await computeSha256(file);
    const version = detail.value?.version ?? 'unknown';
    const objectKey = `releases/${version}/${file.name}`;
    pendingPackages.value.push({
      platform,
      arch,
      fileName: file.name,
      objectKey,
      size: file.size,
      sha256,
      ed25519Signature: '',
      clientVisible,
      file
    });
  } catch (e: any) {
    ElMessage.warning(e.message || '无法处理该文件');
  }
};

const registerPackage = async (index: number) => {
  if (!detail.value) return;
  const pkg = pendingPackages.value[index];
  if (!pkg) return;
  await addReleasePackage(detail.value.version, {
    platform: pkg.platform,
    arch: pkg.arch,
    fileName: pkg.fileName,
    objectKey: pkg.objectKey,
    size: pkg.size,
    sha256: pkg.sha256,
    ed25519Signature: pkg.ed25519Signature,
    clientVisible: pkg.clientVisible
  });
  ElMessage.success('制品已登记');
  pendingPackages.value.splice(index, 1);
  await openRelease(detail.value.version);
  await loadReleases();
};

const removePendingPackage = (index: number) => {
  pendingPackages.value.splice(index, 1);
};

const handlePublish = async (version: string) => {
  await ElMessageBox.confirm(`确认发布 ${version}？发布前会校验版本日志和下载地址；旧制品校验能力仍保留。`, '发布确认', { type: 'warning' });
  await publishRelease(version);
  ElMessage.success('版本已发布');
  await loadReleases();
  if (detail.value?.version === version) {
    await openRelease(version);
  }
};

const handleDelete = async (version: string) => {
  await ElMessageBox.confirm(`确认删除 ${version} 及其 COS 制品？`, '删除确认', { type: 'warning' });
  const res = await deleteRelease(version);
  ElMessage.success(`已删除 ${res.version}`);
  detailVisible.value = false;
  detail.value = undefined;
  await loadReleases();
};

const formatTime = (value?: string) => {
  if (!value) {
    return '-';
  }
  return new Date(value).toLocaleString();
};

const formatBytes = (value: number) => {
  if (!value) {
    return '0 B';
  }
  const units = ['B', 'KB', 'MB', 'GB'];
  let size = value;
  let unitIndex = 0;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex += 1;
  }
  return `${size.toFixed(size >= 10 || unitIndex === 0 ? 0 : 1)} ${units[unitIndex]}`;
};

onMounted(loadReleases);
</script>

<style scoped lang="scss">
.summary-row {
  margin-bottom: 16px;
}

.table-card,
.detail-card,
.detail-block {
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

.form-number,
.full-width {
  width: 100%;
}

:deep(.form-number .el-input__wrapper) {
  width: 100%;
}

:deep(.form-number .el-input__inner) {
  text-align: left !important;
}

.notes-upload-area,
.package-upload-area {
  margin-bottom: 12px;
}

.notes-file-info {
  padding: 8px 0;
}

.pending-packages {
  margin-top: 12px;
}

.pending-package-item {
  margin-bottom: 12px;
  padding: 12px;
  border: 1px solid var(--el-border-color-light);
  border-radius: var(--app-radius-md);

  .pending-package-actions {
    margin-top: 10px;
    display: flex;
    align-items: center;
    gap: 8px;
  }
}
</style>
