# Managing Sensitive Data with Docker Secrets

This guide demonstrates how to create, inspect, and securely mount sensitive data (like passwords, API keys, or certificates) into a container using **Docker Secrets**. 

> **Note:** Docker Secrets are natively supported in **Docker Swarm** mode. If you are using standalone Docker Compose without Swarm, secrets are mounted from local files rather than the Swarm secret store.

---

### 1. Create a Secret
Create a secret by piping a value via standard input (`stdin`) into the `docker secret create` command. Using the `-` flag tells Docker to read the secret value from the pipe rather than a file.

```bash
echo "Test2" | docker secret create Test2 -
```
**Output:**
```text
fdlhyz6a79gc8i7go5nr4kwls
```
*(Docker returns the unique ID of the newly created secret).*

---

### 2. List Existing Secrets
Verify that your secret was created and check its metadata using `ls`. For security reasons, Docker never displays the actual secret value in this view.

```bash
docker secret ls
```
**Output:**
```text
ID                          NAME      DRIVER    CREATED              UPDATED
iy6etf0v9u8cgni63124zhljk   Test1               About a minute ago   About a minute ago
```

---

### 3. Inspect a Secret
View detailed low-level metadata (such as creation timestamps, version index, and labels) in JSON format. Again, the sensitive payload remains hidden.

```bash
docker secret inspect Test1
```
**Output:**
```json
[
    {
        "ID": "iy6etf0v9u8cgni63124zhljk",
        "Version": {
            "Index": 2504359
        },
        "CreatedAt": "2026-09-04T07:07:35.306141755Z",
        "UpdatedAt": "2026-09-04T07:07:35.306141755Z",
        "Spec": {
            "Name": "Test1",
            "Labels": {}
        }
    }
]
```

---

### 4. Configure `docker-compose.yml`
To grant a service access to an existing secret, declare it at the top level with `external: true` and attach it under the specific service definition.

```yaml
services:
  app:
    image: your-image:latest
    ports:
      - "8080:80"
    secrets:
      - Test1

secrets:
  Test1:
    external: true
```

---

### 5. Verify the Secret Inside the Container
Once the stack or service is deployed, Docker mounts the secret as an in-memory file inside the container at `/run/secrets/<secret_name>`.

1. **Open an interactive shell inside the running container:**
   ```bash
   docker exec -it <container_name_or_id> /bin/sh
   ```

2. **Navigate to the secrets directory and read the value:**
   ```bash
   cd /run/secrets
   ls
   cat Test1
   ```
