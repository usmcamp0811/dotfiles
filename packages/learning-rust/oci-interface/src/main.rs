use oci_distribution::client::{Client, ClientConfig, ClientProtocol, Config, ImageLayer};
use oci_distribution::{secrets::RegistryAuth, Reference};
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

    // Read file to push
    let file_path = "/config/packages/learning-rust/oci-interface/example.txt";
    fs::write(file_path, "Hello, OCI from RUST!")?; // Create the file if it doesn't exist
    let content = fs::read(file_path)?;
    if content.is_empty() {
        return Err("File is empty!".into());
    }
    // Create a tar archive in-memory
    let mut tar_buffer = Vec::new();
    {
        let mut tar_builder = Builder::new(Cursor::new(&mut tar_buffer));
        let mut file = fs::File::open(file_path)?;
        tar_builder.append_file("example.txt", &mut file)?;
        tar_builder.finish()?;
    } // Dropping tar_builder ensures the data is flushed to tar_buffer

    println!("Tar buffer size: {}", tar_buffer.len());
    if tar_buffer.is_empty() {
        return Err("Tar archive is empty!".into());
    }
    // Create an ImageLayer
    let layer = ImageLayer::new(
        tar_buffer.clone(),
        "application/vnd.oci.image.layer.v1.tar+gzip".to_string(),
        None,
    );
    println!("Layer size: {}", layer.data.len());
    if layer.data.is_empty() {
        return Err("ImageLayer is empty!".into());
    }

    use oci_distribution::client::Config;
    use oci_distribution::manifest::OciImageManifest;

    println!("Pushing to OCI registry!");

    client
        .push(
            &reference,
            &[layer.clone()],
            Config::new(
                vec![],
                "application/vnd.oci.image.config.v1+json".to_string(),
                None,
            ), // Empty image config
            &RegistryAuth::Anonymous,
            Some(OciImageManifest::default()), // Provide a default manifest
        )
        .await?;

    println!("Pushed successfully!");

    // Fetch metadata
    println!("Fetching manifest digest from OCI registry...");
    let _manifest_digest = client
        .fetch_manifest_digest(&reference, &RegistryAuth::Anonymous)
        .await?;

    println!("Fetched manifest digest successfully!");

    Ok(())
}
