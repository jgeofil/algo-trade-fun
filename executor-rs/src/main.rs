use tracing::info;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_env_filter("info")
        .init();

    info!("executor bootstrapped - TODO: wire gRPC + RPC ingest");

    if let Err(err) = tokio::signal::ctrl_c().await {
        tracing::error!(error = %err, "Failed to install CTRL+C handler");
    }

    info!("executor shutdown");
}
