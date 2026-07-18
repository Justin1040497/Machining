import request from '@/utils/request';
import type {
  CreatePackageRequest,
  CreateReleaseRequest,
  CreateReleaseResponse,
  DashboardResponse,
  DeleteReleaseResponse,
  DiagnosticsResponse,
  DownloadEventRecord,
  HealthResponse,
  IpBlockRule,
  PageResponse,
  ReleaseDetail,
  ReleaseListResponse,
  ReleasePackage,
  UpdateCheckRecord,
  UpdateReleaseDownloadUrlsRequest,
  UploadUrlResponse
} from './types';

export const listReleases = (): Promise<ReleaseListResponse> => {
  return request({
    url: '/api/v1/admin/releases',
    method: 'get'
  });
};

export const getRelease = (version: string): Promise<ReleaseDetail> => {
  return request({
    url: `/api/v1/admin/releases/${encodeURIComponent(version)}`,
    method: 'get'
  });
};

export const createRelease = (data: CreateReleaseRequest): Promise<CreateReleaseResponse> => {
  return request({
    url: '/api/v1/admin/releases',
    method: 'post',
    data
  });
};

export const addReleasePackage = (version: string, data: CreatePackageRequest): Promise<ReleasePackage> => {
  return request({
    url: `/api/v1/admin/releases/${encodeURIComponent(version)}/packages`,
    method: 'post',
    data
  });
};

export const updateReleaseNotes = (version: string, notes: string, notesObjectKey?: string): Promise<ReleaseDetail> => {
  return request({
    url: `/api/v1/admin/releases/${encodeURIComponent(version)}/notes`,
    method: 'put',
    data: { notes, notesObjectKey }
  });
};


export const updateReleaseDownloadUrls = (version: string, data: UpdateReleaseDownloadUrlsRequest): Promise<ReleaseDetail> => {
  return request({
    url: `/api/v1/admin/releases/${encodeURIComponent(version)}/download-urls`,
    method: 'put',
    data
  });
};

export const updateReleaseBuildNumber = (version: string, buildNumber: number): Promise<ReleaseDetail> => {
  return request({
    url: `/api/v1/admin/releases/${encodeURIComponent(version)}/build-number`,
    method: 'patch',
    data: { buildNumber }
  });
};

export const publishRelease = (version: string): Promise<ReleaseDetail> => {
  return request({
    url: `/api/v1/admin/releases/${encodeURIComponent(version)}`,
    method: 'patch',
    data: { status: 'published' }
  });
};

export const deleteRelease = (version: string): Promise<DeleteReleaseResponse> => {
  return request({
    url: `/api/v1/admin/releases/${encodeURIComponent(version)}`,
    method: 'delete'
  });
};

export const getUploadUrl = (key: string): Promise<UploadUrlResponse> => {
  return request({
    url: '/api/v1/admin/upload-url',
    method: 'get',
    params: { key }
  });
};

export const getDashboard = (): Promise<DashboardResponse> => {
  return request({
    url: '/api/v1/admin/dashboard',
    method: 'get'
  });
};

export const listUpdateChecks = (params: Record<string, unknown>): Promise<PageResponse<UpdateCheckRecord>> => {
  return request({
    url: '/api/v1/admin/update-checks',
    method: 'get',
    params
  });
};

export const listDownloadEvents = (params: Record<string, unknown>): Promise<PageResponse<DownloadEventRecord>> => {
  return request({
    url: '/api/v1/admin/download-events',
    method: 'get',
    params
  });
};

export const listIpBlocks = (params: Record<string, unknown>): Promise<PageResponse<IpBlockRule>> => {
  return request({
    url: '/api/v1/admin/ip-blocks',
    method: 'get',
    params
  });
};

export const createIpBlock = (data: { ipAddress: string; reason?: string }): Promise<IpBlockRule> => {
  return request({
    url: '/api/v1/admin/ip-blocks',
    method: 'post',
    data
  });
};

export const disableIpBlock = (id: number): Promise<{ id: number; enabled: boolean }> => {
  return request({
    url: `/api/v1/admin/ip-blocks/${id}/disable`,
    method: 'post'
  });
};

export const getDiagnostics = (): Promise<DiagnosticsResponse> => {
  return request({
    url: '/api/v1/admin/diagnostics',
    method: 'get'
  });
};

export const getHealth = (): Promise<HealthResponse> => {
  return request({
    url: '/api/v1/health',
    method: 'get'
  });
};
