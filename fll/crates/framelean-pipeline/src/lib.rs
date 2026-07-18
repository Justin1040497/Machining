use std::error::Error;
use std::fmt::{self, Display, Formatter};

use framelean_core::{EngineError, ErrorKind, NodeId, TaskId};
use framelean_media::processor::{
    ProcessInput, ProcessOutput, ProcessingStage, Processor, ProcessorContext, ProcessorError,
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NodeKind {
    Source,
    Demuxer,
    PacketProcessor,
    Decoder,
    VideoProcessor,
    AudioProcessor,
    Encoder,
    Muxer,
    Sink,
}

pub struct ExecutionContext {
    task_id: TaskId,
}

impl ExecutionContext {
    pub fn new(task_id: TaskId) -> Self {
        Self { task_id }
    }

    pub fn task_id(&self) -> &TaskId {
        &self.task_id
    }

    fn processor_context(&self, node_id: &NodeId) -> ProcessorContext {
        ProcessorContext::new(self.task_id.clone(), node_id.clone())
    }
}

pub trait Node: Send {
    fn id(&self) -> &NodeId;
    fn kind(&self) -> NodeKind;
    fn stage(&self) -> ProcessingStage;

    fn process(
        &mut self,
        input: ProcessInput,
        context: &mut ExecutionContext,
    ) -> PipelineResult<ProcessOutput>;
}

struct ProcessorNode {
    id: NodeId,
    processor: Box<dyn Processor>,
}

impl ProcessorNode {
    fn new(id: NodeId, processor: Box<dyn Processor>) -> Self {
        Self { id, processor }
    }
}

impl Node for ProcessorNode {
    fn id(&self) -> &NodeId {
        &self.id
    }

    fn kind(&self) -> NodeKind {
        match self.stage() {
            ProcessingStage::Packet => NodeKind::PacketProcessor,
            ProcessingStage::Video => NodeKind::VideoProcessor,
            ProcessingStage::Audio => NodeKind::AudioProcessor,
        }
    }

    fn stage(&self) -> ProcessingStage {
        self.processor.metadata().stage()
    }

    fn process(
        &mut self,
        input: ProcessInput,
        context: &mut ExecutionContext,
    ) -> PipelineResult<ProcessOutput> {
        if input.stage() != self.stage() {
            return Err(PipelineError::InputStageMismatch {
                expected: self.stage(),
                actual: input.stage(),
            });
        }

        let mut processor_context = context.processor_context(&self.id);
        self.processor
            .process(input, &mut processor_context)
            .map_err(|source| PipelineError::Processor {
                node_id: self.id.clone(),
                source,
            })
    }
}

pub struct PipelineBuilder {
    nodes: Vec<Box<dyn Node>>,
    stage: Option<ProcessingStage>,
}

impl PipelineBuilder {
    pub fn new() -> Self {
        Self {
            nodes: Vec::new(),
            stage: None,
        }
    }

    pub fn add_processor(&mut self, processor: Box<dyn Processor>) -> PipelineResult<&mut Self> {
        let stage = processor.metadata().stage();
        if let Some(expected) = self.stage
            && expected != stage
        {
            return Err(PipelineError::MixedStages {
                expected,
                actual: stage,
            });
        }

        let node_number = self.nodes.len() + 1;
        let node_id = NodeId::new(format!("processor-{node_number}"))
            .expect("generated node identifiers are non-empty");
        self.nodes
            .push(Box::new(ProcessorNode::new(node_id, processor)));
        self.stage = Some(stage);
        Ok(self)
    }

    pub fn build(self) -> PipelineResult<Pipeline> {
        let stage = self.stage.ok_or(PipelineError::Empty)?;
        Ok(Pipeline {
            nodes: self.nodes,
            stage,
        })
    }
}

impl Default for PipelineBuilder {
    fn default() -> Self {
        Self::new()
    }
}

pub struct Pipeline {
    nodes: Vec<Box<dyn Node>>,
    stage: ProcessingStage,
}

impl Pipeline {
    pub fn stage(&self) -> ProcessingStage {
        self.stage
    }

    pub fn node_count(&self) -> usize {
        self.nodes.len()
    }

    pub fn validate_input(&self, input: &ProcessInput) -> PipelineResult<()> {
        if input.stage() != self.stage {
            return Err(PipelineError::InputStageMismatch {
                expected: self.stage,
                actual: input.stage(),
            });
        }
        Ok(())
    }

    pub fn execute(
        &mut self,
        input: ProcessInput,
        context: &mut ExecutionContext,
    ) -> PipelineResult<ProcessOutput> {
        self.validate_input(&input)?;

        let node_count = self.nodes.len();
        let mut current = Some(input);

        for (index, node) in self.nodes.iter_mut().enumerate() {
            let input = current
                .take()
                .expect("each pipeline node receives exactly one input");
            let output = node.process(input, context)?;
            if output.stage() != self.stage {
                return Err(PipelineError::OutputStageMismatch {
                    node_id: node.id().clone(),
                    expected: self.stage,
                    actual: output.stage(),
                });
            }

            if index + 1 == node_count {
                return Ok(output);
            }
            current = Some(output.into());
        }

        unreachable!("a pipeline is always built with at least one node")
    }
}

#[derive(Debug, PartialEq, Eq)]
pub enum PipelineError {
    Empty,
    MixedStages {
        expected: ProcessingStage,
        actual: ProcessingStage,
    },
    InputStageMismatch {
        expected: ProcessingStage,
        actual: ProcessingStage,
    },
    OutputStageMismatch {
        node_id: NodeId,
        expected: ProcessingStage,
        actual: ProcessingStage,
    },
    Processor {
        node_id: NodeId,
        source: ProcessorError,
    },
}

impl Display for PipelineError {
    fn fmt(&self, formatter: &mut Formatter<'_>) -> fmt::Result {
        match self {
            Self::Empty => formatter.write_str("pipeline must contain at least one processor"),
            Self::MixedStages { expected, actual } => {
                write!(
                    formatter,
                    "pipeline stage is {expected}, cannot add {actual} processor"
                )
            }
            Self::InputStageMismatch { expected, actual } => {
                write!(
                    formatter,
                    "pipeline expects {expected} input, received {actual}"
                )
            }
            Self::OutputStageMismatch {
                node_id,
                expected,
                actual,
            } => write!(
                formatter,
                "node {node_id} returned {actual} output in {expected} pipeline"
            ),
            Self::Processor { node_id, source } => {
                write!(formatter, "processor node {node_id} failed: {source}")
            }
        }
    }
}

impl Error for PipelineError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match self {
            Self::Processor { source, .. } => Some(source),
            _ => None,
        }
    }
}

impl From<PipelineError> for EngineError {
    fn from(error: PipelineError) -> Self {
        let message = error.to_string();
        Self::with_source(ErrorKind::Pipeline, message, error)
    }
}

pub type PipelineResult<T> = std::result::Result<T, PipelineError>;

#[cfg(test)]
mod tests {
    use std::sync::{Arc, Mutex};

    use framelean_core::{ErrorKind, ProcessorId};
    use framelean_media::processor::{ProcessorMetadata, ProcessorResult};
    use framelean_media::{AudioFrame, MediaBuffer, MediaPacket, StreamId, VideoFrame};

    use super::*;

    struct PassthroughProcessor {
        metadata: ProcessorMetadata,
    }

    impl PassthroughProcessor {
        fn new(id: &str, stage: ProcessingStage) -> Self {
            Self {
                metadata: metadata(id, stage),
            }
        }
    }

    impl Processor for PassthroughProcessor {
        fn metadata(&self) -> &ProcessorMetadata {
            &self.metadata
        }

        fn process(
            &mut self,
            input: ProcessInput,
            _context: &mut ProcessorContext,
        ) -> ProcessorResult<ProcessOutput> {
            Ok(passthrough(input))
        }
    }

    struct CountingProcessor {
        metadata: ProcessorMetadata,
        label: &'static str,
        order: Arc<Mutex<Vec<&'static str>>>,
    }

    impl Processor for CountingProcessor {
        fn metadata(&self) -> &ProcessorMetadata {
            &self.metadata
        }

        fn process(
            &mut self,
            input: ProcessInput,
            _context: &mut ProcessorContext,
        ) -> ProcessorResult<ProcessOutput> {
            self.order.lock().unwrap().push(self.label);
            Ok(passthrough(input))
        }
    }

    struct FailingProcessor {
        metadata: ProcessorMetadata,
    }

    impl Processor for FailingProcessor {
        fn metadata(&self) -> &ProcessorMetadata {
            &self.metadata
        }

        fn process(
            &mut self,
            _input: ProcessInput,
            _context: &mut ProcessorContext,
        ) -> ProcessorResult<ProcessOutput> {
            Err(ProcessorError::failed("expected failure"))
        }
    }

    struct WrongOutputProcessor {
        metadata: ProcessorMetadata,
    }

    impl Processor for WrongOutputProcessor {
        fn metadata(&self) -> &ProcessorMetadata {
            &self.metadata
        }

        fn process(
            &mut self,
            _input: ProcessInput,
            _context: &mut ProcessorContext,
        ) -> ProcessorResult<ProcessOutput> {
            Ok(ProcessOutput::Audio(AudioFrame::new(
                StreamId::new(0),
                None,
                MediaBuffer::new(vec![9]),
            )))
        }
    }

    fn metadata(id: &str, stage: ProcessingStage) -> ProcessorMetadata {
        ProcessorMetadata::new(ProcessorId::new(id).unwrap(), id, stage).unwrap()
    }

    fn passthrough(input: ProcessInput) -> ProcessOutput {
        match input {
            ProcessInput::Packet(value) => ProcessOutput::Packet(value),
            ProcessInput::Video(value) => ProcessOutput::Video(value),
            ProcessInput::Audio(value) => ProcessOutput::Audio(value),
        }
    }

    fn video_input() -> ProcessInput {
        ProcessInput::Video(VideoFrame::new(
            StreamId::new(0),
            None,
            MediaBuffer::new(vec![1, 2, 3]),
        ))
    }

    fn context() -> ExecutionContext {
        ExecutionContext::new(TaskId::new("task-test").unwrap())
    }

    fn assert_stage_pipeline_succeeds(stage: ProcessingStage, input: ProcessInput) {
        let mut builder = PipelineBuilder::new();
        builder
            .add_processor(Box::new(PassthroughProcessor::new("first", stage)))
            .unwrap();
        builder
            .add_processor(Box::new(PassthroughProcessor::new("second", stage)))
            .unwrap();

        let output = builder
            .build()
            .unwrap()
            .execute(input, &mut context())
            .unwrap();

        assert_eq!(output.stage(), stage);
    }

    #[test]
    fn same_stage_processor_chains_support_packet_video_and_audio() {
        assert_stage_pipeline_succeeds(
            ProcessingStage::Packet,
            ProcessInput::Packet(MediaPacket::new(
                StreamId::new(0),
                None,
                MediaBuffer::new(vec![1]),
            )),
        );
        assert_stage_pipeline_succeeds(ProcessingStage::Video, video_input());
        assert_stage_pipeline_succeeds(
            ProcessingStage::Audio,
            ProcessInput::Audio(AudioFrame::new(
                StreamId::new(0),
                None,
                MediaBuffer::new(vec![1]),
            )),
        );
    }

    #[test]
    fn passthrough_moves_non_empty_buffer_without_copying() {
        let input = video_input();
        let ProcessInput::Video(frame) = &input else {
            panic!("expected video input");
        };
        let original_pointer = frame.buffer().as_ptr();

        let mut builder = PipelineBuilder::new();
        builder
            .add_processor(Box::new(PassthroughProcessor::new(
                "passthrough",
                ProcessingStage::Video,
            )))
            .unwrap();
        let output = builder
            .build()
            .unwrap()
            .execute(input, &mut context())
            .unwrap();
        let ProcessOutput::Video(frame) = output else {
            panic!("expected video output");
        };

        assert!(!frame.buffer().is_empty());
        assert_eq!(original_pointer, frame.buffer().as_ptr());
    }

    #[test]
    fn processors_execute_in_order_and_stop_on_failure() {
        let order = Arc::new(Mutex::new(Vec::new()));
        let counting = |id, label| CountingProcessor {
            metadata: metadata(id, ProcessingStage::Video),
            label,
            order: Arc::clone(&order),
        };
        let mut builder = PipelineBuilder::new();
        builder
            .add_processor(Box::new(counting("first", "first")))
            .unwrap();
        builder
            .add_processor(Box::new(FailingProcessor {
                metadata: metadata("failure", ProcessingStage::Video),
            }))
            .unwrap();
        builder
            .add_processor(Box::new(counting("last", "last")))
            .unwrap();

        let error = builder
            .build()
            .unwrap()
            .execute(video_input(), &mut context())
            .unwrap_err();

        match error {
            PipelineError::Processor { node_id, source } => {
                assert_eq!(node_id.as_str(), "processor-2");
                assert_eq!(source, ProcessorError::failed("expected failure"));
            }
            other => panic!("expected structured processor error, received {other:?}"),
        }
        assert_eq!(*order.lock().unwrap(), vec!["first"]);
    }

    #[test]
    fn input_stage_is_validated_before_first_processor() {
        let order = Arc::new(Mutex::new(Vec::new()));
        let mut builder = PipelineBuilder::new();
        builder
            .add_processor(Box::new(CountingProcessor {
                metadata: metadata("video", ProcessingStage::Video),
                label: "called",
                order: Arc::clone(&order),
            }))
            .unwrap();
        let input = ProcessInput::Packet(MediaPacket::new(
            StreamId::new(0),
            None,
            MediaBuffer::new(vec![1]),
        ));

        let error = builder
            .build()
            .unwrap()
            .execute(input, &mut context())
            .unwrap_err();

        assert!(matches!(error, PipelineError::InputStageMismatch { .. }));
        assert!(order.lock().unwrap().is_empty());
    }

    #[test]
    fn builder_rejects_mixed_stages() {
        let mut builder = PipelineBuilder::new();
        builder
            .add_processor(Box::new(PassthroughProcessor::new(
                "video",
                ProcessingStage::Video,
            )))
            .unwrap();

        let error = builder
            .add_processor(Box::new(PassthroughProcessor::new(
                "audio",
                ProcessingStage::Audio,
            )))
            .err()
            .expect("mixed stages must be rejected");

        assert!(matches!(error, PipelineError::MixedStages { .. }));
    }

    #[test]
    fn pipeline_rejects_wrong_output_stage() {
        let order = Arc::new(Mutex::new(Vec::new()));
        let mut builder = PipelineBuilder::new();
        builder
            .add_processor(Box::new(WrongOutputProcessor {
                metadata: metadata("wrong-output", ProcessingStage::Video),
            }))
            .unwrap();
        builder
            .add_processor(Box::new(CountingProcessor {
                metadata: metadata("after-wrong-output", ProcessingStage::Video),
                label: "called",
                order: Arc::clone(&order),
            }))
            .unwrap();

        let error = builder
            .build()
            .unwrap()
            .execute(video_input(), &mut context())
            .unwrap_err();

        assert!(matches!(error, PipelineError::OutputStageMismatch { .. }));
        assert!(order.lock().unwrap().is_empty());
    }

    #[test]
    fn pipeline_error_converts_in_owning_crate() {
        let error = EngineError::from(PipelineError::Empty);
        assert_eq!(error.kind(), ErrorKind::Pipeline);
        assert!(
            std::error::Error::source(&error)
                .unwrap()
                .downcast_ref::<PipelineError>()
                .is_some()
        );
    }

    #[test]
    fn node_kinds_reserve_future_boundaries() {
        let reserved = [
            NodeKind::Source,
            NodeKind::Demuxer,
            NodeKind::Decoder,
            NodeKind::Encoder,
            NodeKind::Muxer,
            NodeKind::Sink,
        ];
        assert_eq!(reserved.len(), 6);
    }
}
