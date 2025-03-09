use oci_distribution::{client, secrets::RegistryAuth, Reference};
use std::{fs, error::Error};

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let client = client::Client::default();
    let registry = "localhost:5000";
    let image_name = "test-artifact";
    let tag = "latest";
    let reference = Reference::with_tag(registry, image_name, tag)?;

    // Read file to push
    let file_path = "example.txt";
    fs::write(file_path, "Hello, OCI!")?; // Create the file if it doesn't exist
    let content = fs::read(file_path)?;

    // Push artifact
    println!("Pushing to OCI registry...");
    client
        .push(&reference, content.clone(), None, RegistryAuth::Anonymous)
        .await?;
    println!("Pushed successfully!");

    // Pull artifact
    println!("Pulling from OCI registry...");
    let image = client.fetch(&reference, None, RegistryAuth::Anonymous).await?;
    
    // Print pulled content
    println!("Pulled content: {}", String::from_utf8_lossy(&image.content));
    
    Ok(())
}
