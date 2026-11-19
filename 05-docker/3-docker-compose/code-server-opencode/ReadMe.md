# 1. Log into your Docker Hub account
docker login

# 2. Build and tag the image (replace 'yourusername' and 'your-app-name')
docker build -t yourusername/your-app-name:latest .

# 3. Push the image to Docker Hub
docker push yourusername/your-app-name:latest

The command docker build -t yourusername/your-app-name:latest . automatically finds your Dockerfile because of that tiny dot (.) at the very end. In terminal language, a dot means "the current directory."