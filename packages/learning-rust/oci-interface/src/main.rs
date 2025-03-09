use oci_distribution::client::{Client, ClientConfig, Config, ImageLayer};
use oci_distribution::{secrets::RegistryAuth, Reference};
use std::{collections::HashMap, error::Error, fs};

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let mut client = Client::new(ClientConfig::default());

    let registry = "localhost:5000";
    let image_name = "test-artifact";
    let tag = "latest";

    let reference = Reference::with_tag(
        registry.to_string(),
        image_name.to_string(),
        tag.to_string(),
    );

    // Read file to push
    let file_path = "example.txt";
    fs::write(file_path, "Hello, OCI!")?; // Create the file if it doesn't exist
    let content = fs::read(file_path)?;

    // Create an ImageLayer
    let layer = ImageLayer::new(
        content,
        "application/vnd.oci.image.layer.v1.tar".to_string(),
        None,
    );

    // Push artifact
    println!("Pushing to OCI registry...");
    client
        .push(
            &reference,
            &[layer], // Image layers
            Config::new(
                vec![],
                "application/vnd.oci.image.config.v1+json".to_string(),
                None,
            ), // Empty image config
            &RegistryAuth::Anonymous,
            None,
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
