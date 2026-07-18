use std::sync::Arc;

use framelean_core::{EngineError, EngineErrorCode, ProcessorId, Result, TaskId};
use framelean_decision::{DecisionService, InputMediaRequirements};
use framelean_media::capability::BackendCatalogProvider;
use framelean_media::processor::{ProcessOutput, ProcessorMetadata};
use framelean_pipeline::{ExecutionContext, Pipeline, PipelineBuilder};
use framelean_plugin::{Plugin, PluginError, PluginRegistry, ProcessorFactory};

use crate::analysis::{
    AnalysisAssembly, build_failure, build_success, collect_catalog, response_warnings,
};
use crate::{
    AnalysisServices, AnalysisSnapshotPolicy, AnalysisSnapshotStore, AnalyzeMediaResponse,
    AnalyzeTaskRequest, ConfigurationConflict, FifoScheduler, PipelineSpec,
    RecalculateConfigurationRequest, RecalculateConfigurationResponse, Scheduler, Task,
    TaskRequest,
};

pub struct EngineRuntime {
    registry: PluginRegistry,
    scheduler: FifoScheduler,
    next_task_number: u64,
    analysis_services: Option<AnalysisServices>,
    analysis_snapshots: Option<AnalysisSnapshotStore>,
    next_analysis_number: u64,
}

impl EngineRuntime {
    pub fn new() -> Self {
        Self {
            registry: PluginRegistry::new(),
            scheduler: FifoScheduler::new(),
            next_task_number: 1,
            analysis_services: None,
            analysis_snapshots: None,
            next_analysis_number: 1,
        }
    }

    pub fn with_analysis_services(
        services: AnalysisServices,
        snapshot_policy: AnalysisSnapshotPolicy,
    ) -> Self {
        let mut runtime = Self::new();
        runtime.analysis_services = Some(services);
        runtime.analysis_snapshots = Some(AnalysisSnapshotStore::new(snapshot_policy));
        runtime
    }

    pub fn analyze_media(&mut self, request: AnalyzeTaskRequest) -> Result<AnalyzeMediaResponse> {
        let analysis_id =
            framelean_core::AnalysisId::new(format!("analysis-{}", self.next_analysis_number))?;
        self.next_analysis_number = self.next_analysis_number.checked_add(1).ok_or_else(|| {
            EngineError::new(framelean_core::ErrorKind::Runtime, "analysis id overflow")
        })?;

        let services = self.analysis_services.as_ref().ok_or_else(|| {
            EngineError::new(
                framelean_core::ErrorKind::Runtime,
                "analysis services are not configured",
            )
        })?;
        let analyzer = Arc::clone(&services.analyzer);
        let environment_provider = Arc::clone(&services.environment);
        let monitor = Arc::clone(&services.resource_monitor);
        let native_providers = services.native_backend_providers.clone();
        let capability_resolver = Arc::clone(&services.capability_resolver);
        let recommendation_engine = Arc::clone(&services.recommendation_engine);
        let estimator_policy = services.estimator_policy.clone();

        let analyzed = match analyzer.analyze(&request.media_request) {
            Ok(analyzed) => analyzed,
            Err(error) => return Ok(build_failure(analysis_id, request.task_mode, error)),
        };
        let (media, source_fingerprint) = analyzed.into_parts();
        let requirements = InputMediaRequirements::from_media_analysis(&media);
        let environment = environment_provider.snapshot()?;
        let resource_sample = monitor.sample().ok();
        let plugin_catalog = self.registry.backend_catalog()?;
        let collected_catalog = collect_catalog(&native_providers, plugin_catalog)?;
        let catalog = collected_catalog.catalog;
        let capabilities = capability_resolver.resolve(
            &requirements,
            request.task_mode,
            &environment,
            &catalog,
        )?;
        let recommendation =
            recommendation_engine.recommend(&requirements, &capabilities, resource_sample.as_ref());
        let (response, snapshot) = build_success(
            analysis_id,
            &request,
            AnalysisAssembly {
                media,
                requirements,
                source_fingerprint,
                environment,
                resource_sample,
                catalog,
                native_backend_count: collected_catalog.native_backend_count,
                plugin_backend_count: collected_catalog.plugin_backend_count,
                capabilities,
                recommendation,
                estimator_policy,
            },
        );
        self.analysis_snapshots
            .as_mut()
            .expect("analysis snapshot store is configured with analysis services")
            .insert(snapshot)?;
        Ok(response)
    }

    pub fn recalculate_configuration(
        &mut self,
        request: RecalculateConfigurationRequest,
    ) -> Result<RecalculateConfigurationResponse> {
        let services = self.analysis_services.as_ref().ok_or_else(|| {
            EngineError::new(
                framelean_core::ErrorKind::Runtime,
                "analysis services are not configured",
            )
        })?;
        let capability_resolver = Arc::clone(&services.capability_resolver);
        let recommendation_engine = Arc::clone(&services.recommendation_engine);
        let size_estimator = services.size_estimator.clone();
        let estimator_policy = services.estimator_policy.clone();
        let snapshot = self
            .analysis_snapshots
            .as_mut()
            .ok_or_else(|| {
                EngineError::new(
                    framelean_core::ErrorKind::Snapshot,
                    "analysis snapshot store is not configured",
                )
            })?
            .get_mut(&request.analysis_id)?;

        if snapshot.revision != request.expected_revision {
            return Err(EngineError::with_code(
                framelean_core::ErrorKind::Snapshot,
                EngineErrorCode::AnalysisRevisionConflict,
                "analysis revision does not match the current snapshot",
            ));
        }
        let current_fingerprint = framelean_analysis::SourceFingerprint::from_local_file(
            snapshot.media_request.source.path(),
        )
        .map_err(|error| {
            EngineError::with_source_code(
                framelean_core::ErrorKind::Snapshot,
                EngineErrorCode::AnalysisSourceChanged,
                "analysis source can no longer be fingerprinted",
                error,
            )
        })?;
        if current_fingerprint != snapshot.source_fingerprint {
            return Err(EngineError::with_code(
                framelean_core::ErrorKind::Snapshot,
                EngineErrorCode::AnalysisSourceChanged,
                "analysis source fingerprint changed",
            ));
        }

        let requirements = InputMediaRequirements::from_media_analysis(&snapshot.media);
        let capabilities = capability_resolver.resolve(
            &requirements,
            snapshot.task_mode,
            &snapshot.environment,
            &snapshot.backend_catalog,
        )?;
        let recommendation = recommendation_engine.recommend(
            &requirements,
            &capabilities,
            snapshot.resource_sample.as_ref(),
        );
        let presets =
            framelean_decision::fixed_presets(&requirements, snapshot.task_mode, &capabilities);
        let custom_target_size = framelean_decision::CustomTargetSizeOptions::from_context(
            &capabilities,
            estimator_policy.as_ref(),
            snapshot.media.file_size.value(),
        );
        let resolution = DecisionService.resolve_selection(
            &request.selection,
            &requirements,
            snapshot.task_mode,
            &capabilities,
            size_estimator
                .as_deref()
                .zip(estimator_policy.as_ref())
                .map(|(estimator, policy)| {
                    (estimator as &dyn framelean_decision::SizeEstimator, policy)
                }),
        );
        let (resolved_configuration, conflicts) = match resolution {
            Ok(resolved) => (Some(resolved), Vec::new()),
            Err(conflict) => (
                None,
                vec![ConfigurationConflict {
                    code: conflict.code,
                    field: conflict.field,
                    message: conflict.message,
                }],
            ),
        };
        if let Some(resolved) = &resolved_configuration {
            snapshot.revision = snapshot.revision.next()?;
            snapshot.capabilities = capabilities.clone();
            snapshot.recommendation = recommendation.clone();
            snapshot.presets = presets.clone();
            snapshot.custom_target_size = custom_target_size.clone();
            snapshot.resolved_configuration = Some(resolved.clone());
        }
        let warnings = response_warnings(&snapshot.media, &capabilities);

        Ok(RecalculateConfigurationResponse {
            schema_version: "1.0".to_owned(),
            analysis_id: request.analysis_id,
            analysis_revision: snapshot.revision,
            configuration_status: if capabilities.available {
                framelean_decision::ConfigurationStatus::Available
            } else {
                framelean_decision::ConfigurationStatus::Unavailable
            },
            capabilities,
            recommendation,
            presets,
            custom_target_size,
            selection: request.selection,
            resolved_configuration,
            conflicts,
            warnings,
            error: None,
        })
    }

    pub fn analysis_snapshot_count(&self) -> usize {
        self.analysis_snapshots
            .as_ref()
            .map_or(0, AnalysisSnapshotStore::len)
    }

    pub fn register_plugin(&mut self, plugin: &dyn Plugin) -> Result<()> {
        plugin
            .register(&mut self.registry)
            .map_err(EngineError::from)
    }

    pub fn submit(&mut self, request: TaskRequest) -> Result<TaskId> {
        let task_id = TaskId::new(format!("task-{}", self.next_task_number))?;
        self.next_task_number += 1;
        self.scheduler
            .enqueue(Task::from_request(task_id.clone(), request))?;
        Ok(task_id)
    }

    pub fn queued_task_count(&self) -> usize {
        self.scheduler.len()
    }

    pub fn run_next(&mut self) -> Result<Option<Task>> {
        let Some(mut task) = self.scheduler.dequeue() else {
            return Ok(None);
        };
        task.start()?;

        let result = self.execute_task(&mut task);
        match result {
            Ok(output) => task.complete(output)?,
            Err(error) => task.fail(error)?,
        }
        Ok(Some(task))
    }

    fn execute_task(&mut self, task: &mut Task) -> Result<ProcessOutput> {
        let processor_ids = task.pipeline().processors().to_vec();
        let mut pipeline = self.build_pipeline(&PipelineSpec::new(processor_ids))?;
        let input = task.take_input()?;
        let mut context = ExecutionContext::new(task.id().clone());
        pipeline
            .execute(input, &mut context)
            .map_err(EngineError::from)
    }

    fn build_pipeline(&self, specification: &PipelineSpec) -> Result<Pipeline> {
        let mut builder = PipelineBuilder::new();
        for requested_id in specification.processors() {
            let factory = self
                .registry
                .factory(requested_id)
                .map_err(EngineError::from)?;
            self.validate_factory(requested_id, factory)?;

            let processor = factory.create().map_err(EngineError::from)?;
            self.validate_processor(requested_id, factory.metadata(), processor.metadata())?;
            builder
                .add_processor(processor)
                .map_err(EngineError::from)?;
        }
        builder.build().map_err(EngineError::from)
    }

    fn validate_factory(
        &self,
        requested_id: &ProcessorId,
        factory: &dyn ProcessorFactory,
    ) -> Result<()> {
        let actual_id = factory.metadata().id();
        if actual_id != requested_id {
            return Err(PluginError::FactoryMetadataMismatch {
                requested: requested_id.clone(),
                actual: actual_id.clone(),
            }
            .into());
        }
        Ok(())
    }

    fn validate_processor(
        &self,
        requested_id: &ProcessorId,
        factory_metadata: &ProcessorMetadata,
        processor_metadata: &ProcessorMetadata,
    ) -> Result<()> {
        if processor_metadata.id() != requested_id {
            return Err(PluginError::ProcessorMetadataMismatch {
                requested: requested_id.clone(),
                actual: processor_metadata.id().clone(),
            }
            .into());
        }
        if processor_metadata.stage() != factory_metadata.stage() {
            return Err(PluginError::ProcessorStageMismatch {
                expected: factory_metadata.stage(),
                actual: processor_metadata.stage(),
            }
            .into());
        }
        Ok(())
    }
}

impl Default for EngineRuntime {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use std::sync::Arc;
    use std::sync::atomic::{AtomicUsize, Ordering};

    use framelean_core::{ErrorKind, ProcessorId};
    use framelean_media::processor::{
        ProcessInput, ProcessingStage, Processor, ProcessorContext, ProcessorError, ProcessorResult,
    };
    use framelean_media::{AudioFrame, MediaBuffer, StreamId, VideoFrame};
    use framelean_plugin::{PluginMetadata, PluginResult};

    use super::*;
    use crate::TaskState;

    enum Behavior {
        Passthrough,
        Fail,
    }

    struct TestProcessor {
        metadata: ProcessorMetadata,
        calls: Arc<AtomicUsize>,
        behavior: Behavior,
    }

    impl Processor for TestProcessor {
        fn metadata(&self) -> &ProcessorMetadata {
            &self.metadata
        }

        fn process(
            &mut self,
            input: ProcessInput,
            _context: &mut ProcessorContext,
        ) -> ProcessorResult<ProcessOutput> {
            self.calls.fetch_add(1, Ordering::SeqCst);
            match self.behavior {
                Behavior::Passthrough => Ok(match input {
                    ProcessInput::Packet(value) => ProcessOutput::Packet(value),
                    ProcessInput::Video(value) => ProcessOutput::Video(value),
                    ProcessInput::Audio(value) => ProcessOutput::Audio(value),
                }),
                Behavior::Fail => Err(ProcessorError::failed("runtime fixture failed")),
            }
        }
    }

    struct TestFactory {
        metadata: ProcessorMetadata,
        created_metadata: ProcessorMetadata,
        calls: Arc<AtomicUsize>,
        fail: bool,
    }

    impl ProcessorFactory for TestFactory {
        fn metadata(&self) -> &ProcessorMetadata {
            &self.metadata
        }

        fn create(&self) -> PluginResult<Box<dyn Processor>> {
            Ok(Box::new(TestProcessor {
                metadata: self.created_metadata.clone(),
                calls: Arc::clone(&self.calls),
                behavior: if self.fail {
                    Behavior::Fail
                } else {
                    Behavior::Passthrough
                },
            }))
        }
    }

    struct TestPlugin {
        metadata: PluginMetadata,
        factories: Vec<TestFactory>,
    }

    impl Plugin for TestPlugin {
        fn metadata(&self) -> &PluginMetadata {
            &self.metadata
        }

        fn register(&self, registry: &mut PluginRegistry) -> PluginResult<()> {
            for factory in &self.factories {
                registry.register_factory(Box::new(TestFactory {
                    metadata: factory.metadata.clone(),
                    created_metadata: factory.created_metadata.clone(),
                    calls: Arc::clone(&factory.calls),
                    fail: factory.fail,
                }))?;
            }
            Ok(())
        }
    }

    fn metadata(id: &str, stage: ProcessingStage) -> ProcessorMetadata {
        ProcessorMetadata::new(ProcessorId::new(id).unwrap(), id, stage).unwrap()
    }

    fn plugin(factory: TestFactory) -> TestPlugin {
        TestPlugin {
            metadata: PluginMetadata::new("test.plugin", "Test Plugin").unwrap(),
            factories: vec![factory],
        }
    }

    fn factory(
        id: &str,
        stage: ProcessingStage,
        calls: Arc<AtomicUsize>,
        fail: bool,
    ) -> TestFactory {
        let metadata = metadata(id, stage);
        TestFactory {
            created_metadata: metadata.clone(),
            metadata,
            calls,
            fail,
        }
    }

    fn video_request(processors: Vec<ProcessorId>) -> TaskRequest {
        TaskRequest::new(
            PipelineSpec::new(processors),
            ProcessInput::Video(VideoFrame::new(
                StreamId::new(0),
                None,
                MediaBuffer::new(vec![1, 2, 3]),
            )),
        )
    }

    #[test]
    fn runtime_composes_duplicate_factory_entries_into_completed_task() {
        let calls = Arc::new(AtomicUsize::new(0));
        let processor_id = ProcessorId::new("test.passthrough").unwrap();
        let plugin = plugin(factory(
            processor_id.as_str(),
            ProcessingStage::Video,
            Arc::clone(&calls),
            false,
        ));
        let mut runtime = EngineRuntime::new();
        runtime.register_plugin(&plugin).unwrap();
        runtime
            .submit(video_request(vec![processor_id.clone(), processor_id]))
            .unwrap();

        let task = runtime.run_next().unwrap().unwrap();

        assert_eq!(task.state(), TaskState::Completed);
        assert!(matches!(task.output(), Some(ProcessOutput::Video(_))));
        assert!(task.failure().is_none());
        assert_eq!(calls.load(Ordering::SeqCst), 2);
    }

    #[test]
    fn processor_failure_is_saved_on_failed_task() {
        let processor_id = ProcessorId::new("test.failure").unwrap();
        let plugin = plugin(factory(
            processor_id.as_str(),
            ProcessingStage::Video,
            Arc::new(AtomicUsize::new(0)),
            true,
        ));
        let mut runtime = EngineRuntime::new();
        runtime.register_plugin(&plugin).unwrap();
        runtime.submit(video_request(vec![processor_id])).unwrap();

        let task = runtime.run_next().unwrap().unwrap();

        assert_eq!(task.state(), TaskState::Failed);
        assert!(task.output().is_none());
        assert_eq!(task.failure().unwrap().kind(), ErrorKind::Pipeline);
    }

    #[test]
    fn input_stage_mismatch_fails_before_processor_runs() {
        let calls = Arc::new(AtomicUsize::new(0));
        let processor_id = ProcessorId::new("test.video").unwrap();
        let plugin = plugin(factory(
            processor_id.as_str(),
            ProcessingStage::Video,
            Arc::clone(&calls),
            false,
        ));
        let mut runtime = EngineRuntime::new();
        runtime.register_plugin(&plugin).unwrap();
        runtime
            .submit(TaskRequest::new(
                PipelineSpec::new(vec![processor_id]),
                ProcessInput::Audio(AudioFrame::new(
                    StreamId::new(0),
                    None,
                    MediaBuffer::new(vec![1]),
                )),
            ))
            .unwrap();

        let task = runtime.run_next().unwrap().unwrap();

        assert_eq!(task.state(), TaskState::Failed);
        assert_eq!(calls.load(Ordering::SeqCst), 0);
        assert_eq!(task.failure().unwrap().kind(), ErrorKind::Pipeline);
    }

    #[test]
    fn processor_metadata_contract_is_checked_defensively() {
        let requested = ProcessorId::new("test.requested").unwrap();
        let mut mismatched = factory(
            requested.as_str(),
            ProcessingStage::Video,
            Arc::new(AtomicUsize::new(0)),
            false,
        );
        mismatched.created_metadata = metadata("test.actual", ProcessingStage::Video);
        let plugin = plugin(mismatched);
        let mut runtime = EngineRuntime::new();
        runtime.register_plugin(&plugin).unwrap();
        runtime.submit(video_request(vec![requested])).unwrap();

        let task = runtime.run_next().unwrap().unwrap();

        assert_eq!(task.state(), TaskState::Failed);
        assert_eq!(task.failure().unwrap().kind(), ErrorKind::Plugin);
    }

    #[test]
    fn factory_metadata_contract_is_checked_defensively() {
        let requested = ProcessorId::new("test.requested-factory").unwrap();
        let factory = factory(
            "test.actual-factory",
            ProcessingStage::Video,
            Arc::new(AtomicUsize::new(0)),
            false,
        );
        let runtime = EngineRuntime::new();

        let error = runtime.validate_factory(&requested, &factory).unwrap_err();

        assert_eq!(error.kind(), ErrorKind::Plugin);
        assert!(error.message().contains("test.actual-factory"));
        assert!(error.message().contains("test.requested-factory"));
    }

    #[test]
    fn processor_stage_contract_is_checked_defensively() {
        let requested = ProcessorId::new("test.stage").unwrap();
        let mut mismatched = factory(
            requested.as_str(),
            ProcessingStage::Video,
            Arc::new(AtomicUsize::new(0)),
            false,
        );
        mismatched.created_metadata = metadata(requested.as_str(), ProcessingStage::Audio);
        let plugin = plugin(mismatched);
        let mut runtime = EngineRuntime::new();
        runtime.register_plugin(&plugin).unwrap();
        runtime.submit(video_request(vec![requested])).unwrap();

        let task = runtime.run_next().unwrap().unwrap();

        assert_eq!(task.state(), TaskState::Failed);
        assert_eq!(task.failure().unwrap().kind(), ErrorKind::Plugin);
    }

    #[test]
    fn unknown_processor_id_fails_task() {
        let mut runtime = EngineRuntime::new();
        runtime
            .submit(video_request(vec![
                ProcessorId::new("test.unknown").unwrap(),
            ]))
            .unwrap();

        let task = runtime.run_next().unwrap().unwrap();

        assert_eq!(task.state(), TaskState::Failed);
        assert_eq!(task.failure().unwrap().kind(), ErrorKind::Plugin);
    }

    #[test]
    fn fifo_scheduler_preserves_submission_order() {
        let calls = Arc::new(AtomicUsize::new(0));
        let processor_id = ProcessorId::new("test.fifo").unwrap();
        let plugin = plugin(factory(
            processor_id.as_str(),
            ProcessingStage::Video,
            calls,
            false,
        ));
        let mut runtime = EngineRuntime::new();
        runtime.register_plugin(&plugin).unwrap();
        let first = runtime
            .submit(video_request(vec![processor_id.clone()]))
            .unwrap();
        let second = runtime.submit(video_request(vec![processor_id])).unwrap();

        assert_eq!(runtime.run_next().unwrap().unwrap().id(), &first);
        assert_eq!(runtime.run_next().unwrap().unwrap().id(), &second);
    }

    #[test]
    fn empty_pipeline_spec_fails_task() {
        let mut runtime = EngineRuntime::new();
        runtime.submit(video_request(Vec::new())).unwrap();

        let task = runtime.run_next().unwrap().unwrap();

        assert_eq!(task.state(), TaskState::Failed);
        assert_eq!(task.failure().unwrap().kind(), ErrorKind::Pipeline);
    }
}
