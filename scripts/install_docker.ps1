# Idempotent: skips if Docker CLI already works. Otherwise installs Docker Desktop via winget (may need admin).
if (Get-Command docker -ErrorAction SilentlyContinue) {
    Write-Host "Docker is already available:"
    docker version
    exit 0
}
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget not found. Install Docker Desktop from https://www.docker.com/products/docker-desktop/"
}
Write-Host "Installing Docker Desktop (winget)..."
winget install -e --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements
Write-Host "Finish Docker Desktop first-run wizard, then open a new terminal and run: docker version"
