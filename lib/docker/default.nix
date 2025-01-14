{ lib, ... }:
with lib; rec {
  pushDockerImage = { pkgs, dockerImage }:
    let
      pushDockerImageScript = pkgs.writeShellScriptBin "push-docker-image" ''
        set -x
        # Default image name and tag from provided dockerImage metadata
        defaultImageName="${dockerImage.imageName}"
        defaultTag="${dockerImage.imageTag}"

        # Parse named arguments
        while [ $# -gt 0 ]; do
          case "$1" in
            --image-name=*)
              imageName="''${1#*=}"
              ;;
            --tag=*)
              imageTag="''${1#*=}"
              ;;
            --repo-url=*)
              repoUrl="''${1#*=}" 
              ;;
            *)
              echo "Unknown option: $1"
              exit 1
              ;;
          esac
          shift
        done


        # Set defaults if arguments were not provided
        imageName="''${imageName:-$defaultImageName}"
        imageTag="''${imageTag:-$defaultTag}"
        repoUrl="''${repoUrl:+$repoUrl/}"  

        # Full image reference
        fullImage="$repoUrl$imageName:$imageTag"

        # Load the Docker image
        echo "Loading Docker image from ${dockerImage}..."
        ${pkgs.docker}/bin/docker load < "${dockerImage}"

        # Tag the Docker image
        echo "Tagging Docker image as $defaultImageName:$defaultTag -> $fullImage..."
        ${pkgs.docker}/bin/docker tag "$defaultImageName:$defaultTag" "$fullImage"

        # Push the Docker image to the specified repository
        echo "Pushing Docker image to $fullImage..."
        ${pkgs.docker}/bin/docker push "$fullImage"
      '';
    in
    pushDockerImageScript;
}
