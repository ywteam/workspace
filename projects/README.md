# Yellow Software Development

## Development Environment

Use the following command to create a development environment for the project.


### Dev Container 
```bash	
cd ./.devcontainer &&
IMAGE_NAME="ywteam/ydk-team:latest" &&
docker build --no-cache --build-arg USER_ID=$(id -u) --build-arg GROUP_ID=$(id -g) -t "${IMAGE_NAME}" . && 
docker run --rm -it  -v "./scripts:/usr/local/lib" "${IMAGE_NAME}" /bin/bash
```


## Legacy Projects

- git@ssh.dev.azure.com:v3/yellowsec/yellowsec.cloud/yellowsec.workspace