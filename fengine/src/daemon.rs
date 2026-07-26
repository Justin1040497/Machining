use std::fs;
use std::io::{self, BufReader, BufWriter, Read, Write};
use std::net::{TcpListener, TcpStream};
use std::path::{Path, PathBuf};
use std::process::{Child, ChildStdin, Command, Stdio};
use std::sync::mpsc::{self, Receiver, Sender, TryRecvError};
use std::thread;
use std::time::{Duration, Instant};

use framelean_core::{EngineError, ErrorKind, Result};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::protocol::{
    OutputEnvelope, PROTOCOL_VERSION, RequestEnvelope, WorkerCommand, WorkerOutput, WorkerResponse,
    read_request_frame, write_output_frame,
};

const POLL_INTERVAL: Duration = Duration::from_millis(50);
const HEARTBEAT_INTERVAL: Duration = Duration::from_secs(4);
const AUTH_TIMEOUT: Duration = Duration::from_secs(2);
const MAX_TOKEN_BYTES: usize = 128;
const MAX_FRAME_BYTES: usize = 16 * 1024 * 1024;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DaemonEndpoint {
    pub host: String,
    pub port: u16,
    pub token: String,
    pub pid: u32,
}

struct EndpointGuard {
    path: PathBuf,
}

impl Drop for EndpointGuard {
    fn drop(&mut self) {
        let _ = fs::remove_file(&self.path);
    }
}

struct ChildGuard {
    child: Child,
    armed: bool,
}

impl ChildGuard {
    fn new(child: Child) -> Self {
        Self { child, armed: true }
    }

    fn disarm(&mut self) {
        self.armed = false;
    }
}

impl Drop for ChildGuard {
    fn drop(&mut self) {
        if self.armed {
            let _ = self.child.kill();
            let _ = self.child.wait();
        }
    }
}

enum ClientInput {
    Request(u64, Box<RequestEnvelope>),
    Closed(u64),
    Failed(u64),
}

pub fn serve_daemon(snapshot_dir: PathBuf, endpoint_file: PathBuf) -> Result<()> {
    fs::create_dir_all(&snapshot_dir).map_err(|error| {
        EngineError::with_source(
            ErrorKind::Runtime,
            "cannot create FEngine snapshot directory",
            error,
        )
    })?;
    if let Some(parent) = endpoint_file.parent() {
        fs::create_dir_all(parent).map_err(|error| {
            EngineError::with_source(
                ErrorKind::Runtime,
                "cannot create FEngine endpoint directory",
                error,
            )
        })?;
    }
    let lock_path = endpoint_file.with_extension("lock");
    let daemon_lock = fs::OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(false)
        .open(&lock_path)
        .map_err(|error| {
            EngineError::with_source(ErrorKind::Runtime, "cannot open FEngine daemon lock", error)
        })?;
    daemon_lock.try_lock().map_err(|error| {
        EngineError::new(
            ErrorKind::Runtime,
            format!("FEngine daemon endpoint is already in use: {error}"),
        )
    })?;

    let listener = TcpListener::bind(("127.0.0.1", 0)).map_err(|error| {
        EngineError::with_source(ErrorKind::Runtime, "cannot bind FEngine daemon", error)
    })?;
    listener.set_nonblocking(true).map_err(|error| {
        EngineError::with_source(
            ErrorKind::Runtime,
            "cannot configure FEngine daemon listener",
            error,
        )
    })?;
    let address = listener.local_addr().map_err(|error| {
        EngineError::with_source(
            ErrorKind::Runtime,
            "cannot read FEngine daemon address",
            error,
        )
    })?;
    let token = Uuid::new_v4().to_string();

    let executable = std::env::current_exe().map_err(|error| {
        EngineError::with_source(
            ErrorKind::Runtime,
            "cannot locate FEngine executable",
            error,
        )
    })?;
    let child = Command::new(executable)
        .arg("serve")
        .arg("--snapshot-dir")
        .arg(&snapshot_dir)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::inherit())
        .spawn()
        .map_err(|error| {
            EngineError::with_source(ErrorKind::Runtime, "cannot start FEngine worker", error)
        })?;
    let mut child = ChildGuard::new(child);
    let mut worker_stdin = BufWriter::new(
        child
            .child
            .stdin
            .take()
            .expect("piped worker stdin must be available"),
    );
    let worker_stdout = child
        .child
        .stdout
        .take()
        .expect("piped worker stdout must be available");
    let (worker_tx, worker_rx) = mpsc::channel();
    let worker_reader = thread::spawn(move || {
        let mut reader = BufReader::new(worker_stdout);
        loop {
            match read_output(&mut reader) {
                Ok(Some(output)) => {
                    if worker_tx.send(Ok(output)).is_err() {
                        break;
                    }
                }
                Ok(None) => {
                    let _ = worker_tx.send(Err("worker output closed".to_owned()));
                    break;
                }
                Err(error) => {
                    let _ = worker_tx.send(Err(error.to_string()));
                    break;
                }
            }
        }
    });

    write_endpoint(
        &endpoint_file,
        &DaemonEndpoint {
            host: "127.0.0.1".to_owned(),
            port: address.port(),
            token: token.clone(),
            pid: std::process::id(),
        },
    )?;
    let endpoint_guard = EndpointGuard {
        path: endpoint_file,
    };

    let result = proxy_loop(
        &listener,
        &token,
        &mut worker_stdin,
        &worker_rx,
        &mut child.child,
    );
    drop(worker_stdin);
    if result.is_err() {
        let _ = child.child.kill();
    }
    let status = child.child.wait().map_err(|error| {
        EngineError::with_source(ErrorKind::Runtime, "cannot wait for FEngine worker", error)
    })?;
    child.disarm();
    drop(endpoint_guard);
    let _ = worker_reader.join();
    drop(daemon_lock);
    result.and_then(|()| {
        if status.success() {
            Ok(())
        } else {
            Err(EngineError::new(
                ErrorKind::Runtime,
                format!("FEngine worker exited with status {status}"),
            ))
        }
    })
}

fn proxy_loop(
    listener: &TcpListener,
    token: &str,
    worker_stdin: &mut BufWriter<ChildStdin>,
    worker_rx: &Receiver<std::result::Result<OutputEnvelope, String>>,
    child: &mut Child,
) -> Result<()> {
    let (client_tx, client_rx) = mpsc::channel();
    let mut client: Option<(u64, BufWriter<TcpStream>)> = None;
    let mut generation = 0_u64;
    let mut session_id: Option<String> = None;
    let mut next_heartbeat = Instant::now() + HEARTBEAT_INTERVAL;

    loop {
        if client.is_none() {
            match listener.accept() {
                Ok((stream, _)) => {
                    if let Some(authenticated) = authenticate(stream, token)? {
                        generation = generation.wrapping_add(1);
                        let reader_stream = authenticated.try_clone().map_err(|error| {
                            EngineError::with_source(
                                ErrorKind::Runtime,
                                "cannot clone FEngine client socket",
                                error,
                            )
                        })?;
                        spawn_client_reader(generation, reader_stream, client_tx.clone());
                        client = Some((generation, BufWriter::new(authenticated)));
                    }
                }
                Err(error) if error.kind() == io::ErrorKind::WouldBlock => {}
                Err(error) => {
                    return Err(EngineError::with_source(
                        ErrorKind::Runtime,
                        "cannot accept FEngine client connection",
                        error,
                    ));
                }
            }
        }

        loop {
            match client_rx.try_recv() {
                Ok(ClientInput::Request(input_generation, request))
                    if client
                        .as_ref()
                        .is_some_and(|(active, _)| *active == input_generation) =>
                {
                    write_request(worker_stdin, &request).map_err(|error| {
                        EngineError::with_source(
                            ErrorKind::Runtime,
                            "cannot forward request to FEngine worker",
                            error,
                        )
                    })?;
                }
                Ok(ClientInput::Closed(input_generation))
                    if client
                        .as_ref()
                        .is_some_and(|(active, _)| *active == input_generation) =>
                {
                    client = None;
                    next_heartbeat = Instant::now();
                }
                Ok(ClientInput::Failed(input_generation))
                    if client
                        .as_ref()
                        .is_some_and(|(active, _)| *active == input_generation) =>
                {
                    client = None;
                    next_heartbeat = Instant::now();
                }
                Ok(ClientInput::Failed(_)) => {}
                Ok(ClientInput::Request(_, _) | ClientInput::Closed(_)) => {}
                Err(TryRecvError::Empty) => break,
                Err(TryRecvError::Disconnected) => {
                    return Err(EngineError::new(
                        ErrorKind::Runtime,
                        "FEngine client reader channel disconnected",
                    ));
                }
            }
        }

        loop {
            match worker_rx.try_recv() {
                Ok(Ok(output)) => {
                    if matches!(
                        &output.output,
                        WorkerOutput::Response(WorkerResponse::Hello { .. })
                    ) {
                        session_id = Some(output.session_id.clone());
                    }
                    if output.request_id == "daemon-heartbeat" {
                        continue;
                    }
                    if let Some((_, writer)) = client.as_mut()
                        && let Err(error) = write_output_frame(writer, &output)
                    {
                        let _ = error;
                        client = None;
                        next_heartbeat = Instant::now();
                    }
                }
                Ok(Err(message)) => {
                    if message == "worker output closed" {
                        let status = child.wait().map_err(|error| {
                            EngineError::with_source(
                                ErrorKind::Runtime,
                                "cannot wait for FEngine worker",
                                error,
                            )
                        })?;
                        return if status.success() {
                            Ok(())
                        } else {
                            Err(EngineError::new(
                                ErrorKind::Runtime,
                                format!("FEngine worker exited with status {status}"),
                            ))
                        };
                    }
                    return Err(EngineError::new(
                        ErrorKind::Runtime,
                        format!("FEngine worker output failed: {message}"),
                    ));
                }
                Err(TryRecvError::Empty) => break,
                Err(TryRecvError::Disconnected) => {
                    return Err(EngineError::new(
                        ErrorKind::Runtime,
                        "FEngine worker output channel disconnected",
                    ));
                }
            }
        }

        if client.is_none()
            && Instant::now() >= next_heartbeat
            && let Some(session_id) = session_id.clone()
        {
            write_request(
                worker_stdin,
                &RequestEnvelope {
                    protocol_version: PROTOCOL_VERSION,
                    session_id: Some(session_id),
                    request_id: "daemon-heartbeat".to_owned(),
                    command: WorkerCommand::Ping,
                },
            )
            .map_err(|error| {
                EngineError::with_source(
                    ErrorKind::Runtime,
                    "cannot send FEngine daemon heartbeat",
                    error,
                )
            })?;
            next_heartbeat = Instant::now() + HEARTBEAT_INTERVAL;
        }

        thread::sleep(POLL_INTERVAL);
    }
}

fn authenticate(mut stream: TcpStream, expected_token: &str) -> Result<Option<TcpStream>> {
    stream.set_nonblocking(false).map_err(|error| {
        EngineError::with_source(
            ErrorKind::Runtime,
            "cannot configure FEngine client socket blocking mode",
            error,
        )
    })?;
    stream
        .set_read_timeout(Some(AUTH_TIMEOUT))
        .map_err(|error| {
            EngineError::with_source(
                ErrorKind::Runtime,
                "cannot configure FEngine client authentication timeout",
                error,
            )
        })?;
    stream.set_nodelay(true).map_err(|error| {
        EngineError::with_source(
            ErrorKind::Runtime,
            "cannot configure FEngine client socket",
            error,
        )
    })?;
    let mut token = Vec::new();
    let mut byte = [0_u8; 1];
    while token.len() <= MAX_TOKEN_BYTES {
        match stream.read_exact(&mut byte) {
            Ok(()) if byte[0] == b'\n' => break,
            Ok(()) => token.push(byte[0]),
            Err(_) => return Ok(None),
        }
    }
    stream.set_read_timeout(None).map_err(|error| {
        EngineError::with_source(
            ErrorKind::Runtime,
            "cannot clear FEngine client authentication timeout",
            error,
        )
    })?;
    if token.len() > MAX_TOKEN_BYTES || token != expected_token.as_bytes() {
        return Ok(None);
    }
    Ok(Some(stream))
}

fn spawn_client_reader(generation: u64, stream: TcpStream, sender: Sender<ClientInput>) {
    thread::spawn(move || {
        let mut reader = BufReader::new(stream);
        loop {
            match read_request_frame(&mut reader) {
                Ok(Some(request)) => {
                    if sender
                        .send(ClientInput::Request(generation, Box::new(request)))
                        .is_err()
                    {
                        break;
                    }
                }
                Ok(None) => {
                    let _ = sender.send(ClientInput::Closed(generation));
                    break;
                }
                Err(error) => {
                    let _ = error;
                    let _ = sender.send(ClientInput::Failed(generation));
                    break;
                }
            }
        }
    });
}

fn write_endpoint(path: &Path, endpoint: &DaemonEndpoint) -> Result<()> {
    let temporary = path.with_extension(format!("tmp-{}", std::process::id()));
    let json = serde_json::to_vec(endpoint).map_err(|error| {
        EngineError::with_source(
            ErrorKind::Runtime,
            "cannot serialize FEngine daemon endpoint",
            error,
        )
    })?;
    let mut options = fs::OpenOptions::new();
    options.write(true).create(true).truncate(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
    }
    let mut file = options.open(&temporary).map_err(|error| {
        EngineError::with_source(
            ErrorKind::Runtime,
            "cannot create FEngine daemon endpoint",
            error,
        )
    })?;
    file.write_all(&json)
        .and_then(|_| file.sync_all())
        .map_err(|error| {
            EngineError::with_source(
                ErrorKind::Runtime,
                "cannot persist FEngine daemon endpoint",
                error,
            )
        })?;
    fs::rename(&temporary, path).map_err(|error| {
        EngineError::with_source(
            ErrorKind::Runtime,
            "cannot publish FEngine daemon endpoint",
            error,
        )
    })
}

fn read_output(reader: &mut impl Read) -> io::Result<Option<OutputEnvelope>> {
    let mut length = [0_u8; 4];
    match reader.read_exact(&mut length) {
        Ok(()) => {}
        Err(error) if error.kind() == io::ErrorKind::UnexpectedEof => return Ok(None),
        Err(error) => return Err(error),
    }
    let length = u32::from_be_bytes(length) as usize;
    if length == 0 || length > MAX_FRAME_BYTES {
        return Err(io::Error::new(
            io::ErrorKind::InvalidData,
            "worker output frame length is invalid",
        ));
    }
    let mut payload = vec![0_u8; length];
    reader.read_exact(&mut payload)?;
    serde_json::from_slice(&payload).map(Some).map_err(|error| {
        io::Error::new(
            io::ErrorKind::InvalidData,
            format!("invalid output JSON: {error}"),
        )
    })
}

fn write_request(writer: &mut impl Write, request: &RequestEnvelope) -> io::Result<()> {
    let payload = serde_json::to_vec(request).map_err(|error| {
        io::Error::new(
            io::ErrorKind::InvalidData,
            format!("cannot serialize request JSON: {error}"),
        )
    })?;
    let length = u32::try_from(payload.len())
        .map_err(|_| io::Error::new(io::ErrorKind::InvalidData, "request is too large"))?;
    writer.write_all(&length.to_be_bytes())?;
    writer.write_all(&payload)?;
    writer.flush()
}
