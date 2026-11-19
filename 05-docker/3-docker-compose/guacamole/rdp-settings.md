https://www.reddit.com/r/unRAID/comments/1hrwa2b/has_anyone_got_a_windows_11_machine_to_be/

I got it to work! I followed this guide: https://jobinbasani.com/2024/12/31/secure-remote-desktop-access-with-apache-guacamole-and-cloudflare/

For the RDP settings I had to use the following:

Protocol = RDP

Hostname = IP of the Windows Box

Port = leave blank

Username = email address for your MS account

Password = password for your MS account

Domain = hostname of my Windows system

Security Mode = leave blank

Ignore Server Certificate = ticked

I also did the following which I don't know whether or not it made a difference:

I added my account to Remote Desktop Users group.

I went to Settings -> Accounts -> Sign-in Options and disabled the "only allow Windows Hello sign-in":