FROM 	mcr.microsoft.com/vscode/devcontainers/universal:linux

## Install yq
RUN sudo apt-get update \
    && sudo apt-get install software-properties-common -y \
    && sudo add-apt-repository ppa:rmescandon/yq \
    && sudo apt-get update \
    && sudo apt-get install yq -y

## Install bicep tools
RUN sudo curl -Lo bicep https://github.com/Azure/bicep/releases/latest/download/bicep-linux-x64 && sudo chmod +x ./bicep && sudo mv ./bicep /usr/local/bin/bicep

## Install Porter
RUN curl -L https://cdn.porter.sh/latest/install-linux.sh | bash
ENV PATH "$PATH:/home/codespace/.porter"

## Install SQL tools
COPY ./webapi/install-sql-tools.sh scripts/
RUN sudo chmod +x scripts/install-sql-tools.sh && sudo scripts/install-sql-tools.sh
