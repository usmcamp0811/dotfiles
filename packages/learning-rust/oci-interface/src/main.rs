use oci_distribution::client::{Client, ClientConfig, ClientProtocol, Config, ImageLayer};
use oci_distribution::{secrets::RegistryAuth, Reference};
use sha2::{Digest, Sha256};
use std::io::{Cursor, Write};
use std::{collections::HashMap, error::Error, fs};
use tar::Builder;

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let mut client = Client::new(ClientConfig {
        protocol: ClientProtocol::Http,
        accept_invalid_hostnames: false,
        accept_invalid_certificates: false,
        extra_root_certificates: vec![],
        platform_resolver: None,
    });

    let registry = "localhost:5000";
    let image_name = "test-artifact";
    let tag = "latest";
    let reference = Reference::with_tag(
        registry.to_string(),
        image_name.to_string(),
        tag.to_string(),
    );

    let file_path = "/config/packages/learning-rust/oci-interface/example.txt";
    fs::write(file_path, "Hello, OCI from RUST!")?;

    let mut tar_buffer = Vec::new();
    {
        let mut tar_builder = Builder::new(Cursor::new(&mut tar_buffer));
        let mut file = fs::File::open(file_path)?;
        tar_builder.append_file("example.txt", &mut file)?;
        tar_builder.finish()?;
    }

    println!("Tar buffer size: {}", tar_buffer.len());
    if tar_buffer.is_empty() {
        return Err("Tar archive is empty!".into());
    }

    // Compute SHA256 digest of the tar buffer
    let mut hasher = Sha256::new();
    hasher.update(&tar_buffer);
    let digest = format!("{:x}", hasher.finalize());

    println!("Computed Digest: sha256:{}", digest);

    // Fix: Wrap digest in a HashMap
    let mut digest_map = HashMap::new();
    digest_map.insert("sha256".to_string(), digest.clone());

    // Create an ImageLayer with the computed digest
    let layer = ImageLayer::new(
        tar_buffer.clone(),
        "application/vnd.oci.image.layer.v1.tar+gzip".to_string(),
        Some(digest_map), // Fix: Provide a HashMap instead of String
    );

    println!("Layer size: {}", layer.data.len());
    if layer.data.is_empty() {
        return Err("ImageLayer is empty!".into());
    }

    let config = Config::new(
        br#"{"created": "2025-03-09T00:00:00Z"}"#.to_vec(),
        "application/vnd.oci.image.config.v1+json".to_string(),
        None,
    );

    println!("Pushing to OCI registry!");
    client
        .push(&reference, &[layer], config, &RegistryAuth::Anonymous, None)
        .await?;

    println!("Pushed successfully!");
    println!("Fetching manifest digest from OCI registry...");

    let _manifest_digest = client
        .fetch_manifest_digest(&reference, &RegistryAuth::Anonymous)
        .await?;

    println!("Fetched manifest digest successfully!");

    Ok(())
}
