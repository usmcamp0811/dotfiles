# README

This is for those who made a bad decision when it came to their OS. 
It allows them to be able to build docker containers with Nix on MacOS.
Additionally it should allow for shells and other Nix things that generally
don't work on Mac. This is because it will run the Nix command in a Docker
container (that is run in a Linux VM...because MacOS).


Usage:

```
mac-nix run gitlab:usmcamp0811/dotfiles#mlflow-serve
```
