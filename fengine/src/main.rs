use std::path::PathBuf;
use std::process::ExitCode;
use std::thread;
use std::time::Duration;

use clap::{Parser, Subcommand, ValueEnum};
use framelean_analysis::{MediaAnalysisStatus, MediaAnalyzeRequest, MediaSource};
use framelean_core::{EngineError, ErrorKind, ProcessorId};
use framelean_engine::{build_default_runtime, serve_daemon, serve_stdio};
use framelean_environment::{EnvironmentSnapshotProvider, ResourceMonitor, SystemEnvironment};
use framelean_media::processor::{
    ProcessInput, ProcessOutput, ProcessingStage, Processor, ProcessorContext, ProcessorMetadata,
    ProcessorResult,
};
use framelean_media::{MediaBuffer, StreamId, VideoFrame};
use framelean_plugin::{Plugin, PluginMetadata, PluginRegistry, PluginResult, ProcessorFactory};
use framelean_runtime::{
    AnalyzeTaskRequest, EngineRuntime, PipelineSpec, RequestContext, TaskMode, TaskRequest,
    TaskState,
};

const DEMO_PROCESSOR_ID: &str = "example.passthrough";

fn main() -> ExitCode {
    let cli = Cli::parse();
    match cli.command {
        None => {
            print_status();
            ExitCode::SUCCESS
        }
        Some(Command::Demo) => match execute_demo() {
            Ok(result) => {
                println!("Demo execution successful");
                println!();
                println!("Task:");
                println!("{:?}", result.task_state);
                println!();
                println!("Processor:");
                println!("{}", result.processor_id);
                ExitCode::SUCCESS
            }
            Err(error) => {
                println!("Demo execution failed");
                println!();
                println!("Reason:");
                println!("{error}");
                ExitCode::FAILURE
            }
        },
        Some(Command::Analyze { path, mode, json }) => execute_analyze(path, mode.into(), json),
        Some(Command::Environment { json }) => execute_environment(json),
        Some(Command::Monitor {
            samples,
            interval_ms,
            json,
        }) => execute_monitor(samples, interval_ms, json),
        Some(Command::Serve { snapshot_dir }) => match serve_stdio(snapshot_dir) {
            Ok(()) => ExitCode::SUCCESS,
            Err(error) => {
                eprintln!("FEngine worker failed: {error}");
                ExitCode::FAILURE
            }
        },
        Some(Command::ServeDaemon {
            snapshot_dir,
            endpoint_file,
        }) => match serve_daemon(snapshot_dir, endpoint_file) {
            Ok(()) => ExitCode::SUCCESS,
            Err(error) => {
                eprintln!("FEngine daemon failed: {error}");
                ExitCode::FAILURE
            }
        },
    }
}

#[derive(Parser)]
#[command(name = "framelean-engine", version = "0.1.0")]
struct Cli {
    #[command(subcommand)]
    command: Option<Command>,
}

#[derive(Subcommand)]
enum Command {
    Demo,
    Analyze {
        path: PathBuf,
        #[arg(long, value_enum)]
        mode: CliTaskMode,
        #[arg(long)]
        json: bool,
    },
    Environment {
        #[arg(long)]
        json: bool,
    },
    Monitor {
        #[arg(long)]
        samples: usize,
        #[arg(long, default_value_t = 1000)]
        interval_ms: u64,
        #[arg(long)]
        json: bool,
    },
    Serve {
        #[arg(long)]
        snapshot_dir: PathBuf,
    },
    ServeDaemon {
        #[arg(long)]
        snapshot_dir: PathBuf,
        #[arg(long)]
        endpoint_file: PathBuf,
    },
}

#[derive(Clone, Copy, ValueEnum)]
enum CliTaskMode {
    VideoCompress,
    VideoConvert,
    AudioCompress,
    AudioConvert,
    ImageCompress,
    ImageConvert,
}

impl From<CliTaskMode> for TaskMode {
    fn from(value: CliTaskMode) -> Self {
        match value {
            CliTaskMode::VideoCompress => Self::VideoCompress,
            CliTaskMode::VideoConvert => Self::VideoConvert,
            CliTaskMode::AudioCompress => Self::AudioCompress,
            CliTaskMode::AudioConvert => Self::AudioConvert,
            CliTaskMode::ImageCompress => Self::ImageCompress,
            CliTaskMode::ImageConvert => Self::ImageConvert,
        }
    }
}

fn execute_analyze(path: PathBuf, mode: TaskMode, json: bool) -> ExitCode {
    match analyze(path, mode) {
        Ok(response) => {
            let exit_code = if response.media_analysis_status == MediaAnalysisStatus::Failed {
                ExitCode::FAILURE
            } else {
                ExitCode::SUCCESS
            };
            if json {
                println!("{}", serde_json::to_string_pretty(&response).unwrap());
            } else {
                println!("Media analysis: {:?}", response.media_analysis_status);
                println!("Configuration: {:?}", response.configuration_status);
                for warning in &response.warnings {
                    eprintln!("Warning {:?}: {}", warning.code, warning.message);
                }
            }
            exit_code
        }
        Err(error) => {
            if json {
                println!(
                    "{}",
                    serde_json::json!({
                        "error": {
                            "code": "ENGINE_ANALYZE_FAILED",
                            "message": error.to_string(),
                        }
                    })
                );
            } else {
                eprintln!("Analysis failed: {error}");
            }
            ExitCode::FAILURE
        }
    }
}

fn analyze(
    path: PathBuf,
    mode: TaskMode,
) -> Result<framelean_runtime::AnalyzeMediaResponse, EngineError> {
    let mut runtime = build_default_runtime()?;
    runtime.analyze_media(AnalyzeTaskRequest {
        task_mode: mode,
        media_request: MediaAnalyzeRequest {
            source: MediaSource::local_file(path)?,
            request_id: None,
            expected_source: None,
        },
        context: RequestContext::default(),
    })
}

fn execute_environment(json: bool) -> ExitCode {
    match SystemEnvironment::new().snapshot() {
        Ok(snapshot) => {
            if json {
                println!("{}", serde_json::to_string_pretty(&snapshot).unwrap());
            } else {
                println!("OS: {:?}", snapshot.operating_system.value);
                println!("Architecture: {}", snapshot.cpu.architecture);
                println!("Logical cores: {}", snapshot.cpu.logical_cores);
            }
            ExitCode::SUCCESS
        }
        Err(error) => {
            eprintln!("Environment detection failed: {error}");
            ExitCode::FAILURE
        }
    }
}

fn execute_monitor(samples: usize, interval_ms: u64, json: bool) -> ExitCode {
    if samples == 0 || interval_ms == 0 {
        eprintln!("samples and interval-ms must be greater than zero");
        return ExitCode::FAILURE;
    }
    let monitor = SystemEnvironment::new();
    let mut values = Vec::with_capacity(samples);
    for index in 0..samples {
        match monitor.sample() {
            Ok(sample) => values.push(sample),
            Err(error) => {
                eprintln!("Resource sampling failed: {error}");
                return ExitCode::FAILURE;
            }
        }
        if index + 1 < samples {
            thread::sleep(Duration::from_millis(interval_ms));
        }
    }
    if json {
        println!("{}", serde_json::to_string_pretty(&values).unwrap());
    } else {
        for sample in values {
            println!(
                "{}: CPU {:?} basis points, memory {:?} bytes",
                sample.sampled_at_unix_ms,
                sample.cpu_usage_basis_points.value,
                sample.used_memory.value.map(|value| value.value())
            );
        }
    }
    ExitCode::SUCCESS
}

fn print_status() {
    println!("FrameLean Engine");
    println!();
    println!("Architecture Foundation v0.1.0");
    println!();
    println!("Components:");
    println!("✓ Core");
    println!("✓ Media Model");
    println!("✓ Processor API");
    println!("✓ Pipeline");
    println!("✓ Plugin Registry");
    println!("✓ Runtime");
    println!();
    println!("Status:");
    println!("Ready");
}

struct DemoResult {
    task_state: TaskState,
    processor_id: ProcessorId,
}

fn execute_demo() -> Result<DemoResult, EngineError> {
    let processor_id = ProcessorId::new(DEMO_PROCESSOR_ID)?;
    let plugin = ExamplePlugin::new(processor_id.clone())?;
    let mut runtime = EngineRuntime::new();
    runtime.register_plugin(&plugin)?;
    runtime.submit(TaskRequest::new(
        PipelineSpec::new(vec![processor_id.clone()]),
        ProcessInput::Video(VideoFrame::new(
            StreamId::new(0),
            None,
            MediaBuffer::new(vec![1]),
        )),
    ))?;

    let task = runtime
        .run_next()?
        .ok_or_else(|| EngineError::new(ErrorKind::Runtime, "demo task was not scheduled"))?;
    if task.state() != TaskState::Completed {
        let failure = task.failure().ok_or_else(|| {
            EngineError::new(ErrorKind::Runtime, "demo task failed without an error")
        })?;
        return Err(EngineError::new(failure.kind(), failure.to_string()));
    }

    Ok(DemoResult {
        task_state: task.state(),
        processor_id,
    })
}

struct PassthroughProcessor {
    metadata: ProcessorMetadata,
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
        Ok(match input {
            ProcessInput::Packet(value) => ProcessOutput::Packet(value),
            ProcessInput::Video(value) => ProcessOutput::Video(value),
            ProcessInput::Audio(value) => ProcessOutput::Audio(value),
        })
    }
}

struct PassthroughFactory {
    metadata: ProcessorMetadata,
}

impl ProcessorFactory for PassthroughFactory {
    fn metadata(&self) -> &ProcessorMetadata {
        &self.metadata
    }

    fn create(&self) -> PluginResult<Box<dyn Processor>> {
        Ok(Box::new(PassthroughProcessor {
            metadata: self.metadata.clone(),
        }))
    }
}

struct ExamplePlugin {
    metadata: PluginMetadata,
    processor_metadata: ProcessorMetadata,
}

impl ExamplePlugin {
    fn new(processor_id: ProcessorId) -> Result<Self, EngineError> {
        Ok(Self {
            metadata: PluginMetadata::new("example.plugin", "Example Plugin")?,
            processor_metadata: ProcessorMetadata::new(
                processor_id,
                "Example Passthrough Processor",
                ProcessingStage::Video,
            )?,
        })
    }
}

impl Plugin for ExamplePlugin {
    fn metadata(&self) -> &PluginMetadata {
        &self.metadata
    }

    fn register(&self, registry: &mut PluginRegistry) -> PluginResult<()> {
        registry.register_factory(Box::new(PassthroughFactory {
            metadata: self.processor_metadata.clone(),
        }))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn serve_command_accepts_snapshot_directory() {
        let cli = Cli::try_parse_from([
            "framelean-engine",
            "serve",
            "--snapshot-dir",
            "/tmp/framelean-snapshots",
        ])
        .unwrap();
        let Some(Command::Serve { snapshot_dir }) = cli.command else {
            panic!("serve command should be parsed");
        };
        assert_eq!(snapshot_dir, PathBuf::from("/tmp/framelean-snapshots"));
    }

    #[test]
    fn serve_command_requires_snapshot_directory() {
        assert!(Cli::try_parse_from(["framelean-engine", "serve"]).is_err());
    }

    #[test]
    fn analyze_command_rejects_the_removed_selection_option() {
        assert!(
            Cli::try_parse_from([
                "framelean-engine",
                "analyze",
                "/tmp/input.mp4",
                "--mode",
                "video-compress",
                "--selection",
                "/tmp/selection.json",
            ])
            .is_err()
        );
    }

    #[test]
    fn serve_daemon_command_accepts_endpoint_and_snapshot_paths() {
        let cli = Cli::try_parse_from([
            "framelean-engine",
            "serve-daemon",
            "--snapshot-dir",
            "/tmp/framelean-snapshots",
            "--endpoint-file",
            "/tmp/framelean-endpoint.json",
        ])
        .unwrap();
        let Some(Command::ServeDaemon {
            snapshot_dir,
            endpoint_file,
        }) = cli.command
        else {
            panic!("serve-daemon command should be parsed");
        };
        assert_eq!(snapshot_dir, PathBuf::from("/tmp/framelean-snapshots"));
        assert_eq!(endpoint_file, PathBuf::from("/tmp/framelean-endpoint.json"));
    }

    #[test]
    fn demo_completes_static_execution_chain() {
        let result = execute_demo().unwrap();

        assert_eq!(result.task_state, TaskState::Completed);
        assert_eq!(result.processor_id.as_str(), DEMO_PROCESSOR_ID);
    }
}
