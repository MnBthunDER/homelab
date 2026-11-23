https://community.home-assistant.io/t/reverse-proxy-using-nginx/196954

https://www.home-assistant.io/docs/configuration/

Reverse proxy setup requires reviewing homeassist log for the ip required to whitelist.

Then setup the whitelist in the \hass\hass-config\configuration.yaml

http:
  use_x_forwarded_for: true
  trusted_proxies: %ip address shown in logs%