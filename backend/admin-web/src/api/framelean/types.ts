export type ReleaseStatus = 'draft' | 'published' | 'archived';
export type ReleasePlatform = 'windows-x64' | 'windows-installer' | 'macos-universal2';

export interface ArtifactRequirement {
  platform: ReleasePlatform;
  arch: string;
  required: boolean;
}

export interface ReleasePackage {
  id: number;
  releaseId: number;
  platform: ReleasePlatform;
  arch: string;
  fileName: string;
  objectKey: string;
  size: number;
  sha256: string;
  ed25519Signature?: string;
  clientVisible: boolean;
  createdAt?: string;
}

export interface ReleaseSummary {
  id: number;
  version: string;
  buildNumber: number;
  channel: string;
  status: ReleaseStatus;
  downloadCount: number;
  createdAt?: string;
  publishedAt?: string;
}

export interface ReleaseDetail extends ReleaseSummary {
  mandatory: boolean;
  minSupportedBuild: number;
  notes?: string;
  notesObjectKey?: string;
  requirements: ArtifactRequirement[];
  packages: ReleasePackage[];
  githubDownloadUrl?: string;
  giteeDownloadUrl?: string;
  backupDownloadUrl?: string;
}

export interface ReleaseListResponse {
  releases: ReleaseSummary[];
}

export interface CreateReleaseRequest {
  version: string;
  buildNumber: number;
  channel: string;
  mandatory: boolean;
  minSupportedBuild: number;
  notes?: string;
  notesObjectKey?: string;
  requiredArtifacts?: ArtifactRequirement[];
  packages?: CreatePackageRequest[];
  githubDownloadUrl?: string;
  giteeDownloadUrl?: string;
  backupDownloadUrl?: string;
}

export interface UpdateReleaseDownloadUrlsRequest {
  githubDownloadUrl?: string;
  giteeDownloadUrl?: string;
  backupDownloadUrl?: string;
}

export interface CreateReleaseResponse {
  id: number;
  version: string;
  status: ReleaseStatus;
}

export interface CreatePackageRequest {
  platform: ReleasePlatform;
  arch: string;
  fileName: string;
  objectKey: string;
  size: number;
  sha256: string;
  ed25519Signature?: string;
  clientVisible?: boolean;
}

export interface DeleteReleaseResponse {
  version: string;
  deleted: boolean;
  deletedObjectKeys: string[];
}

export interface UploadUrlResponse {
  uploadUrl: string;
  expiresAt: string;
}

export interface DashboardResponse {
  totalDownloads: number;
  totalUpdateChecks: number;
  distinctDownloadIps: number;
  distinctCheckIps: number;
  activeBlockedIps: number;
}

export interface PageResponse<T> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
}

export interface UpdateCheckRecord {
  id: number;
  releaseId?: number;
  releaseVersion?: string;
  currentVersion: string;
  currentBuild: number;
  platform: string;
  channel: string;
  installId?: string;
  ipAddress?: string;
  userAgent?: string;
  updateAvailable: boolean;
  blocked: boolean;
  createdAt?: string;
}

export interface DownloadEventRecord {
  id: number;
  releaseId: number;
  releaseVersion?: string;
  platform: string;
  arch: string;
  installId?: string;
  ipAddress?: string;
  createdAt?: string;
}

export interface IpBlockRule {
  id: number;
  ipAddress: string;
  reason?: string;
  enabled: boolean;
  expiresAt?: string;
  createdAt?: string;
  updatedAt?: string;
}

export interface DiagnosticsResponse {
  publicBaseUrl: string;
  cosConfigured: boolean;
  redisConfigured: boolean;
  apiKeyConfigured: boolean;
  updateTicketTtl: string;
  downloadUrlTtl: string;
}

export interface HealthResponse {
  status: string;
}
