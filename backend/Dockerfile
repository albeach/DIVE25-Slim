FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies (using npm install instead of npm ci)
RUN npm install

# Copy source code
COPY . .

# Build if needed (uncomment if you have a build step)
# RUN npm run build

# Expose port
EXPOSE 3000

# Start the application
CMD ["npm", "start"]
