use std::fs;
use std::io::{Read, Write};
use std::net::{Shutdown, TcpStream};
use std::process::{Command, Stdio};
use std::sync::mpsc;
use std::thread;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use framelean_engine::daemon::DaemonEndpoint;
use framelean_engine::protocol::{
    AnalyzeMediaCommand, ClientSourceFacts, HelloCommand, OutputEnvelope, PROTOCOL_VERSION,
    RequestEnvelope, SubmitExecutionCommand, WorkerCommand, WorkerErrorCode, WorkerEvent,
    WorkerOutput, WorkerResponse,
};
use framelean_runtime::{
    ExecutionOutputRequest, ManualConfigurationSelection, ManualSelection, OutputCollisionPolicy,
    RecalculateSelection, TaskMode,
};

#[test]
fn serve_process_uses_only_framed_stdout_for_handshake_ping_and_shutdown() {
    let snapshot_dir = snapshot_directory("protocol");
    let mut child = Command::new(env!("CARGO_BIN_EXE_framelean-engine"))
        .arg("serve")
        .arg("--snapshot-dir")
        .arg(&snapshot_dir)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .expect("worker process should start");
    let mut stdin = child.stdin.take().expect("worker stdin should be piped");
    let stdout = child.stdout.take().expect("worker stdout should be piped");
    let mut stderr = child.stderr.take().expect("worker stderr should be piped");

    let (output_tx, output_rx) = mpsc::channel();
    let stdout_reader = thread::spawn(move || {
        let mut stdout = stdout;
        loop {
            match read_output_frame(&mut stdout) {
                Ok(Some(output)) => {
                    if output_tx.send(Ok(output)).is_err() {
                        break;
                    }
                }
                Ok(None) => break,
                Err(error) => {
                    let _ = output_tx.send(Err(error));
                    break;
                }
            }
        }
    });

    write_request_frame(
        &mut stdin,
        &RequestEnvelope {
            protocol_version: PROTOCOL_VERSION,
            session_id: None,
            request_id: "hello-1".to_owned(),
            command: WorkerCommand::Hello(HelloCommand {
                minimum_protocol_version: PROTOCOL_VERSION,
                maximum_protocol_version: PROTOCOL_VERSION,
                client_name: "integration-test".to_owned(),
                client_version: "1".to_owned(),
            }),
        },
    );
    let hello = receive_output(&output_rx);
    let session_id = hello.session_id.clone();
    assert_eq!(hello.sequence, 1);
    assert!(matches!(
        hello.output,
        WorkerOutput::Response(WorkerResponse::Hello {
            negotiated_protocol_version: PROTOCOL_VERSION,
            resumed: false,
            ..
        })
    ));

    write_request_frame(
        &mut stdin,
        &RequestEnvelope {
            protocol_version: PROTOCOL_VERSION,
            session_id: Some(session_id.clone()),
            request_id: "ping-1".to_owned(),
            command: WorkerCommand::Ping,
        },
    );
    let pong = receive_output(&output_rx);
    assert_eq!(pong.session_id, session_id);
    assert_eq!(pong.sequence, 2);
    assert!(matches!(
        pong.output,
        WorkerOutput::Response(WorkerResponse::Pong)
    ));

    write_request_frame(
        &mut stdin,
        &RequestEnvelope {
            protocol_version: PROTOCOL_VERSION,
            session_id: Some(session_id.clone()),
            request_id: "shutdown-1".to_owned(),
            command: WorkerCommand::Shutdown,
        },
    );
    let shutdown = receive_output(&output_rx);
    let complete = receive_output(&output_rx);
    assert_eq!(shutdown.sequence, 3);
    assert!(matches!(
        shutdown.output,
        WorkerOutput::Response(WorkerResponse::ShutdownAccepted)
    ));
    assert_eq!(complete.sequence, 4);
    assert_eq!(complete.request_id, "shutdown-1");
    assert!(matches!(
        complete.output,
        WorkerOutput::Event(WorkerEvent::ShutdownComplete)
    ));

    drop(stdin);
    let status = child.wait().expect("worker process should be waitable");
    stdout_reader
        .join()
        .expect("stdout reader thread should finish");
    assert!(status.success());
    assert!(
        matches!(
            output_rx.try_recv(),
            Err(mpsc::TryRecvError::Empty | mpsc::TryRecvError::Disconnected)
        ),
        "stdout must not contain unframed or unexpected output"
    );

    let mut diagnostics = String::new();
    stderr
        .read_to_string(&mut diagnostics)
        .expect("worker stderr should be readable");
    assert!(diagnostics.is_empty(), "unexpected stderr: {diagnostics}");
    std::fs::remove_dir_all(snapshot_dir).expect("snapshot fixture should be removable");
}

#[test]
fn invalid_frame_is_reported_as_a_structured_protocol_error() {
    let snapshot_dir = snapshot_directory("invalid-frame");
    let mut child = Command::new(env!("CARGO_BIN_EXE_framelean-engine"))
        .arg("serve")
        .arg("--snapshot-dir")
        .arg(&snapshot_dir)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .expect("worker process should start");
    let mut stdin = child.stdin.take().expect("worker stdin should be piped");
    let mut stdout = child.stdout.take().expect("worker stdout should be piped");
    let mut stderr = child.stderr.take().expect("worker stderr should be piped");

    stdin
        .write_all(&0_u32.to_be_bytes())
        .expect("invalid frame should be writable");
    stdin.flush().expect("invalid frame should be flushed");
    drop(stdin);

    let output = read_output_frame(&mut stdout)
        .expect("worker output should be framed")
        .expect("worker should report the invalid frame");
    assert_eq!(output.request_id, "invalid-frame");
    assert!(matches!(
        output.output,
        WorkerOutput::Error(ref error) if error.code == WorkerErrorCode::InvalidFrame
    ));
    assert!(
        read_output_frame(&mut stdout)
            .expect("worker stdout should end cleanly")
            .is_none()
    );
    assert!(
        !child.wait().expect("worker should be waitable").success(),
        "a malformed protocol frame must terminate the worker unsuccessfully"
    );

    let mut diagnostics = String::new();
    stderr
        .read_to_string(&mut diagnostics)
        .expect("worker stderr should be readable");
    assert!(diagnostics.contains("protocol input failed"));
    std::fs::remove_dir_all(snapshot_dir).expect("snapshot fixture should be removable");
}

#[test]
fn serve_process_analyzes_executes_and_reanalyzes_real_media() {
    let root = snapshot_directory("real-media");
    let snapshot_dir = root.join("snapshots");
    fs::create_dir_all(&root).expect("fixture directory should be creatable");
    let input_path = root.join("input.wav");
    let output_path = root.join("output.wav");
    fs::write(&input_path, pcm_wav_fixture()).expect("WAV fixture should be writable");

    let mut child = Command::new(env!("CARGO_BIN_EXE_framelean-engine"))
        .arg("serve")
        .arg("--snapshot-dir")
        .arg(&snapshot_dir)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .expect("worker process should start");
    let mut stdin = child.stdin.take().expect("worker stdin should be piped");
    let stdout = child.stdout.take().expect("worker stdout should be piped");
    let mut stderr = child.stderr.take().expect("worker stderr should be piped");
    let (output_tx, output_rx) = mpsc::channel();
    let stdout_reader = thread::spawn(move || {
        let mut stdout = stdout;
        loop {
            match read_output_frame(&mut stdout) {
                Ok(Some(output)) => {
                    if output_tx.send(Ok(output)).is_err() {
                        break;
                    }
                }
                Ok(None) => break,
                Err(error) => {
                    let _ = output_tx.send(Err(error));
                    break;
                }
            }
        }
    });

    write_request_frame(
        &mut stdin,
        &RequestEnvelope {
            protocol_version: PROTOCOL_VERSION,
            session_id: None,
            request_id: "hello-real-media".to_owned(),
            command: WorkerCommand::Hello(HelloCommand {
                minimum_protocol_version: PROTOCOL_VERSION,
                maximum_protocol_version: PROTOCOL_VERSION,
                client_name: "real-media-integration-test".to_owned(),
                client_version: "1".to_owned(),
            }),
        },
    );
    let hello = receive_output(&output_rx);
    let session_id = hello.session_id;

    write_request_frame(
        &mut stdin,
        &RequestEnvelope {
            protocol_version: PROTOCOL_VERSION,
            session_id: Some(session_id.clone()),
            request_id: "analyze-input".to_owned(),
            command: WorkerCommand::AnalyzeMedia(AnalyzeMediaCommand {
                client_task_id: "task-real-media".to_owned(),
                client_file_id: "file-real-media".to_owned(),
                source: source_facts(&input_path),
                task_mode: TaskMode::AudioConvert,
                priority: Default::default(),
                force_reanalysis: false,
            }),
        },
    );
    let analysis = loop {
        let output = receive_output(&output_rx);
        assert_not_error(&output);
        if let WorkerOutput::Event(WorkerEvent::AnalysisCompleted { analysis, .. }) = output.output
        {
            break analysis;
        }
    };
    assert!(analysis.error.is_none(), "{:?}", analysis.error);
    let candidate = analysis
        .capabilities
        .as_ref()
        .and_then(|capabilities| capabilities.execution_chains.first())
        .expect("real WAV must expose a stream-copy execution chain");

    write_request_frame(
        &mut stdin,
        &RequestEnvelope {
            protocol_version: PROTOCOL_VERSION,
            session_id: Some(session_id.clone()),
            request_id: "execute-input".to_owned(),
            command: WorkerCommand::SubmitExecution(SubmitExecutionCommand {
                client_task_id: "task-real-media".to_owned(),
                analysis_id: analysis.analysis_id.clone(),
                expected_revision: analysis.analysis_revision,
                selection: RecalculateSelection::Manual(ManualConfigurationSelection {
                    candidate_id: candidate.id.clone(),
                    overrides: ManualSelection::empty(),
                }),
                output: ExecutionOutputRequest {
                    requested_path: output_path.clone(),
                    collision_policy: OutputCollisionPolicy::FailIfExists,
                },
                priority: Default::default(),
            }),
        },
    );
    let mut saw_progress = false;
    loop {
        let output = receive_output(&output_rx);
        assert_not_error(&output);
        match output.output {
            WorkerOutput::Event(WorkerEvent::ExecutionProgress { client_task_id, .. }) => {
                assert_eq!(client_task_id, "task-real-media");
                saw_progress = true;
            }
            WorkerOutput::Event(WorkerEvent::ExecutionCompleted {
                client_task_id,
                output_path: completed_path,
                ..
            }) => {
                assert_eq!(client_task_id, "task-real-media");
                assert_eq!(completed_path, output_path);
                break;
            }
            WorkerOutput::Event(WorkerEvent::ExecutionFailed { message, .. }) => {
                panic!("real media execution failed: {message}");
            }
            _ => {}
        }
    }
    assert!(saw_progress, "real packet processing must emit progress");
    assert!(fs::metadata(&output_path).unwrap().len() > 44);

    write_request_frame(
        &mut stdin,
        &RequestEnvelope {
            protocol_version: PROTOCOL_VERSION,
            session_id: Some(session_id.clone()),
            request_id: "snapshot-after-execution".to_owned(),
            command: WorkerCommand::GetEngineSnapshot,
        },
    );
    loop {
        let output = receive_output(&output_rx);
        assert_not_error(&output);
        if let WorkerOutput::Event(WorkerEvent::EngineSnapshotReady { snapshot, .. }) =
            output.output
        {
            assert!(snapshot.terminal_analyses.iter().any(|entry| {
                entry.client_task_id == "task-real-media"
                    && entry.analysis_id == analysis.analysis_id
                    && entry.succeeded
            }));
            assert!(snapshot.terminal_executions.iter().any(|entry| {
                entry.client_task_id == "task-real-media"
                    && entry.state == framelean_runtime::ExecutionTaskState::Completed
                    && entry.output_path.as_deref() == Some(output_path.as_path())
            }));
            break;
        }
    }

    write_request_frame(
        &mut stdin,
        &RequestEnvelope {
            protocol_version: PROTOCOL_VERSION,
            session_id: Some(session_id.clone()),
            request_id: "analyze-output".to_owned(),
            command: WorkerCommand::AnalyzeMedia(AnalyzeMediaCommand {
                client_task_id: "task-output".to_owned(),
                client_file_id: "file-output".to_owned(),
                source: source_facts(&output_path),
                task_mode: TaskMode::AudioConvert,
                priority: Default::default(),
                force_reanalysis: false,
            }),
        },
    );
    loop {
        let output = receive_output(&output_rx);
        assert_not_error(&output);
        if let WorkerOutput::Event(WorkerEvent::AnalysisCompleted { analysis, .. }) = output.output
        {
            assert!(analysis.error.is_none(), "{:?}", analysis.error);
            break;
        }
    }

    write_request_frame(
        &mut stdin,
        &RequestEnvelope {
            protocol_version: PROTOCOL_VERSION,
            session_id: Some(session_id),
            request_id: "shutdown-real-media".to_owned(),
            command: WorkerCommand::Shutdown,
        },
    );
    loop {
        if matches!(
            receive_output(&output_rx).output,
            WorkerOutput::Event(WorkerEvent::ShutdownComplete)
        ) {
            break;
        }
    }
    drop(stdin);
    assert!(child.wait().expect("worker should be waitable").success());
    stdout_reader.join().expect("stdout reader should finish");
    let mut diagnostics = String::new();
    stderr
        .read_to_string(&mut diagnostics)
        .expect("worker stderr should be readable");
    assert!(diagnostics.is_empty(), "unexpected stderr: {diagnostics}");
    fs::remove_dir_all(root).expect("real media fixture should be removable");
}

#[test]
fn daemon_keeps_the_worker_session_alive_across_client_reconnect() {
    let root = snapshot_directory("daemon-reconnect");
    let snapshot_dir = root.join("snapshots");
    let endpoint_file = root.join("engine-endpoint.json");
    fs::create_dir_all(&root).expect("daemon fixture directory should be creatable");
    let mut daemon = Command::new(env!("CARGO_BIN_EXE_framelean-engine"))
        .arg("serve-daemon")
        .arg("--snapshot-dir")
        .arg(&snapshot_dir)
        .arg("--endpoint-file")
        .arg(&endpoint_file)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .spawn()
        .expect("daemon process should start");

    let endpoint = wait_for_endpoint(&endpoint_file);
    assert_eq!(endpoint.host, "127.0.0.1");
    assert!(!endpoint.token.is_empty());
    let contender = Command::new(env!("CARGO_BIN_EXE_framelean-engine"))
        .arg("serve-daemon")
        .arg("--snapshot-dir")
        .arg(&snapshot_dir)
        .arg("--endpoint-file")
        .arg(&endpoint_file)
        .output()
        .expect("competing daemon should be waitable");
    assert!(
        !contender.status.success(),
        "only one daemon may own an endpoint"
    );
    assert_eq!(wait_for_endpoint(&endpoint_file), endpoint);
    let mut first = connect_daemon(&endpoint);
    write_request_frame(
        &mut first,
        &RequestEnvelope {
            protocol_version: PROTOCOL_VERSION,
            session_id: None,
            request_id: "hello-before-restart".to_owned(),
            command: WorkerCommand::Hello(HelloCommand {
                minimum_protocol_version: PROTOCOL_VERSION,
                maximum_protocol_version: PROTOCOL_VERSION,
                client_name: "daemon-integration-test".to_owned(),
                client_version: "1".to_owned(),
            }),
        },
    );
    let first_hello = read_output_frame(&mut first)
        .expect("first hello frame should decode")
        .expect("first hello should produce a response");
    let session_id = first_hello.session_id.clone();
    assert!(matches!(
        first_hello.output,
        WorkerOutput::Response(WorkerResponse::Hello { resumed: false, .. })
    ));
    first
        .shutdown(Shutdown::Both)
        .expect("first client should disconnect");
    drop(first);
    thread::sleep(Duration::from_millis(200));

    let mut second = connect_daemon(&endpoint);
    write_request_frame(
        &mut second,
        &RequestEnvelope {
            protocol_version: PROTOCOL_VERSION,
            session_id: None,
            request_id: "hello-after-restart".to_owned(),
            command: WorkerCommand::Hello(HelloCommand {
                minimum_protocol_version: PROTOCOL_VERSION,
                maximum_protocol_version: PROTOCOL_VERSION,
                client_name: "daemon-integration-test".to_owned(),
                client_version: "1".to_owned(),
            }),
        },
    );
    let resumed = read_output_frame(&mut second)
        .expect("reconnect hello frame should decode")
        .expect("reconnect hello should produce a response");
    assert_eq!(resumed.session_id, session_id);
    assert!(matches!(
        resumed.output,
        WorkerOutput::Response(WorkerResponse::Hello { resumed: true, .. })
    ));

    write_request_frame(
        &mut second,
        &RequestEnvelope {
            protocol_version: PROTOCOL_VERSION,
            session_id: Some(session_id.clone()),
            request_id: "snapshot-after-restart".to_owned(),
            command: WorkerCommand::GetEngineSnapshot,
        },
    );
    loop {
        let output = read_output_frame(&mut second)
            .expect("snapshot frame should decode")
            .expect("snapshot request should complete");
        assert_not_error(&output);
        if matches!(
            output.output,
            WorkerOutput::Event(WorkerEvent::EngineSnapshotReady { .. })
        ) {
            break;
        }
    }

    write_request_frame(
        &mut second,
        &RequestEnvelope {
            protocol_version: PROTOCOL_VERSION,
            session_id: Some(session_id),
            request_id: "shutdown-daemon".to_owned(),
            command: WorkerCommand::Shutdown,
        },
    );
    loop {
        let output = read_output_frame(&mut second)
            .expect("shutdown frame should decode")
            .expect("shutdown should complete");
        if matches!(
            output.output,
            WorkerOutput::Event(WorkerEvent::ShutdownComplete)
        ) {
            break;
        }
    }
    drop(second);
    let status = daemon.wait().expect("daemon should be waitable");
    assert!(status.success());
    let mut diagnostics = String::new();
    daemon
        .stderr
        .take()
        .expect("daemon stderr should be piped")
        .read_to_string(&mut diagnostics)
        .expect("daemon stderr should be readable");
    assert!(diagnostics.is_empty(), "unexpected stderr: {diagnostics}");
    assert!(
        !endpoint_file.exists(),
        "daemon must remove its endpoint file"
    );
    fs::remove_dir_all(root).expect("daemon fixture should be removable");
}

fn wait_for_endpoint(path: &std::path::Path) -> DaemonEndpoint {
    let deadline = std::time::Instant::now() + Duration::from_secs(5);
    loop {
        if let Ok(json) = fs::read(path)
            && let Ok(endpoint) = serde_json::from_slice(&json)
        {
            return endpoint;
        }
        assert!(
            std::time::Instant::now() < deadline,
            "daemon endpoint did not become ready"
        );
        thread::sleep(Duration::from_millis(20));
    }
}

fn connect_daemon(endpoint: &DaemonEndpoint) -> TcpStream {
    let mut stream = TcpStream::connect((endpoint.host.as_str(), endpoint.port))
        .expect("daemon endpoint should accept a local connection");
    stream
        .set_read_timeout(Some(Duration::from_secs(5)))
        .expect("daemon test socket timeout should be configurable");
    stream
        .write_all(format!("{}\n", endpoint.token).as_bytes())
        .expect("daemon token should be writable");
    stream.flush().expect("daemon token should be flushed");
    stream
}

fn source_facts(path: &std::path::Path) -> ClientSourceFacts {
    ClientSourceFacts {
        path: path.to_path_buf(),
        file_size_bytes: fs::metadata(path).unwrap().len(),
        modified_time_unix_nanos: None,
    }
}

fn assert_not_error(output: &OutputEnvelope) {
    if let WorkerOutput::Error(error) = &output.output {
        panic!("worker returned protocol error: {error:?}");
    }
    if let WorkerOutput::Event(WorkerEvent::WorkFailed { error, .. }) = &output.output {
        panic!("worker work failed: {error:?}");
    }
}

fn pcm_wav_fixture() -> Vec<u8> {
    const SAMPLE_RATE: u32 = 8_000;
    const SAMPLE_COUNT: u32 = 800;
    const CHANNELS: u16 = 1;
    const BITS_PER_SAMPLE: u16 = 16;
    let data_size = SAMPLE_COUNT * u32::from(CHANNELS) * u32::from(BITS_PER_SAMPLE / 8);
    let mut bytes = Vec::with_capacity((44 + data_size) as usize);
    bytes.extend_from_slice(b"RIFF");
    bytes.extend_from_slice(&(36 + data_size).to_le_bytes());
    bytes.extend_from_slice(b"WAVEfmt ");
    bytes.extend_from_slice(&16_u32.to_le_bytes());
    bytes.extend_from_slice(&1_u16.to_le_bytes());
    bytes.extend_from_slice(&CHANNELS.to_le_bytes());
    bytes.extend_from_slice(&SAMPLE_RATE.to_le_bytes());
    let byte_rate = SAMPLE_RATE * u32::from(CHANNELS) * u32::from(BITS_PER_SAMPLE / 8);
    bytes.extend_from_slice(&byte_rate.to_le_bytes());
    let block_align = CHANNELS * (BITS_PER_SAMPLE / 8);
    bytes.extend_from_slice(&block_align.to_le_bytes());
    bytes.extend_from_slice(&BITS_PER_SAMPLE.to_le_bytes());
    bytes.extend_from_slice(b"data");
    bytes.extend_from_slice(&data_size.to_le_bytes());
    for sample in 0..SAMPLE_COUNT {
        let value = if sample % 32 < 16 {
            8_000_i16
        } else {
            -8_000_i16
        };
        bytes.extend_from_slice(&value.to_le_bytes());
    }
    bytes
}

fn snapshot_directory(label: &str) -> std::path::PathBuf {
    let suffix = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("system time should follow the Unix epoch")
        .as_nanos();
    std::env::temp_dir().join(format!(
        "framelean-worker-{label}-{}-{suffix}",
        std::process::id()
    ))
}

fn write_request_frame(writer: &mut impl Write, request: &RequestEnvelope) {
    let payload = serde_json::to_vec(request).expect("request should serialize");
    let length = u32::try_from(payload.len()).expect("test request should fit in one frame");
    writer
        .write_all(&length.to_be_bytes())
        .expect("frame length should be writable");
    writer
        .write_all(&payload)
        .expect("frame body should be writable");
    writer.flush().expect("request should be flushed");
}

fn read_output_frame(reader: &mut impl Read) -> Result<Option<OutputEnvelope>, String> {
    let mut length = [0_u8; 4];
    match reader.read(&mut length[..1]) {
        Ok(0) => return Ok(None),
        Ok(1) => {}
        Ok(_) => unreachable!("single-byte buffer cannot read more than one byte"),
        Err(error) => return Err(error.to_string()),
    }
    reader
        .read_exact(&mut length[1..])
        .map_err(|error| error.to_string())?;
    let mut payload = vec![0; u32::from_be_bytes(length) as usize];
    reader
        .read_exact(&mut payload)
        .map_err(|error| error.to_string())?;
    serde_json::from_slice(&payload)
        .map(Some)
        .map_err(|error| error.to_string())
}

fn receive_output(receiver: &mpsc::Receiver<Result<OutputEnvelope, String>>) -> OutputEnvelope {
    receiver
        .recv_timeout(Duration::from_secs(5))
        .expect("worker should emit a protocol frame")
        .expect("worker frame should decode")
}
