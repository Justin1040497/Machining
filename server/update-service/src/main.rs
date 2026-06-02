use std::env;

use framelean_update_service::{app, ServerConfig};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let bind_addr =
        env::var("FRAMELEAN_UPDATE_BIND_ADDR").unwrap_or_else(|_| "127.0.0.1:8080".to_string());
    let config = ServerConfig::from_env()?;
    let listener = tokio::net::TcpListener::bind(&bind_addr).await?;

    println!("FrameLean update service listening on http://{bind_addr}");
    axum::serve(listener, app(config)).await?;

    Ok(())
}
