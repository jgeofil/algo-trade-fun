use tracing::info;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_env_filter("info")
        .init();

    info!("executor bootstrapped - TODO: wire gRPC + RPC ingest");

    tokio::signal::ctrl_c()
        .await
        .expect("failed to install CTRL+C handler");

    info!("executor shutdown");
}
