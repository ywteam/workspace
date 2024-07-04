FROM yellowteam/ywt-base:latest
# Add cloudflare gpg key
RUN mkdir -p --mode=0755 /usr/share/keyrings && \
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null && \
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared jammy main' | sudo tee /etc/apt/sources.list.d/cloudflared.list && \
apt-get update && \
apt-get install --no-install-recommends -y cloudflared && \